// Copyright (c) 2025, WSO2 LLC. (https://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied. See the License for the
// specific language governing permissions and limitations
// under the License.

import { env } from 'process';
import { PluginContext, MessageDocument, LogDocument } from '../types';
import axios, { AxiosInstance, InternalAxiosRequestConfig } from 'axios';

class MoesifService {
  private context: PluginContext;
  private moesifClient: AxiosInstance;
  private moesifSearchPath: string;
  private moesifApiKey: string;
  private messageActionName: string;
  private logActionName: string;
  // Todo - Cache for messages to avoid frequent queries
  private cachedMessages: MessageDocument[] | null = null;
  private cachedLogs: LogDocument[] | null = null;
  private lastCacheTime: number = 0;
  private cacheTTL: number = 5 * 60 * 1000; // 5 minutes cache TTL

  constructor(context: PluginContext) {
    this.context = context;
    this.messageActionName = env.MOESIF_TRANSLATION_ACTION_NAME || 'translation_action';
    this.logActionName = env.MOESIF_LOG_ACTION_NAME || 'log_action';
    this.cacheTTL = context.config?.cacheTTL || 5 * 60 * 1000; // Default 5 minutes

    // Get Moesif config from environment
    this.moesifApiKey = env.MOESIF_API_KEY || '';
    this.moesifSearchPath = env.MOESIF_SEARCH_PATH || '/v1/search/~/search/events';

    // Initialize Moesif client
    this.moesifClient = this.createMoesifClient();
  }

  /**
   * Create and configure the Moesif axios client with interceptors and retry logic
   */
  private createMoesifClient(): AxiosInstance {
    const baseURL = env.MOESIF_BASE_URL || 'https://api.moesif.com';
    const timeout = parseInt(env.MOESIF_TIMEOUT || '30000', 10); // 30 seconds default
    const maxRetries = parseInt(env.MOESIF_MAX_RETRIES || '3', 10);
    const retryDelay = parseInt(env.MOESIF_RETRY_DELAY || '1000', 10); // 1 second default

    // Create axios instance with configuration
    const client = axios.create({
      baseURL,
      timeout,
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      validateStatus: (status) => status >= 200 && status < 300,
    });

    // Request interceptor - add auth header and log requests
    client.interceptors.request.use(
      (config: AxiosRequestConfigWithMetadata) => {
        // Add authorization header
        if (this.moesifApiKey) {
          config.headers.Authorization = `Bearer ${this.moesifApiKey}`;
        }

        // Add request metadata for retry tracking
        if (!config.metadata) {
          config.metadata = { startTime: Date.now(), retryCount: 0 };
        }

        // Log request details (only in development/debug mode)
        if (env.MOESIF_DEBUG === 'true') {
          console.log('[Moesif Request]', {
            method: config.method?.toUpperCase(),
            url: config.url,
            baseURL: config.baseURL,
            timeout: config.timeout,
          });
        }

        return config;
      },
      (error) => {
        console.error('[Moesif Request Error]:', error.message);
        return Promise.reject(error);
      }
    );

    // Response interceptor - handle retries and log responses
    client.interceptors.response.use(
      (response) => {
        // Log successful response
        if (env.MOESIF_DEBUG === 'true') {
          const config = response.config as AxiosRequestConfigWithMetadata;
          const duration = Date.now() - (config.metadata?.startTime || 0);
          console.log('[Moesif Response]', {
            status: response.status,
            duration: `${duration}ms`,
            dataSize: JSON.stringify(response.data).length,
          });
        }

        return response;
      },
      async (error) => {
        const config = error.config as AxiosRequestConfigWithMetadata;

        // Return if no config or retry mechanism not applicable
        if (!config) {
          return Promise.reject(error);
        }

        // Initialize retry count if not exists
        if (!config.metadata) {
          config.metadata = { retryCount: 0 };
        }

        // Determine if error is retryable
        const isRetryable = this.isRetryableError(error);
        const shouldRetry = isRetryable && config.metadata.retryCount < maxRetries;

        if (shouldRetry) {
          config.metadata.retryCount += 1;

          // Calculate exponential backoff delay
          const backoffDelay = retryDelay * Math.pow(2, config.metadata.retryCount - 1);

          console.warn(
            `[Moesif Retry] Attempt ${config.metadata.retryCount}/${maxRetries} after ${backoffDelay}ms`,
            {
              url: config.url,
              error: error.message,
              status: error.response?.status,
            }
          );

          // Wait before retrying
          await this.delay(backoffDelay);

          // Retry the request
          return client.request(config);
        }

        // Log final error if all retries exhausted or non-retryable
        console.error('[Moesif Error]', {
          url: config.url,
          method: config.method,
          status: error.response?.status,
          message: error.message,
          retries: config.metadata.retryCount,
          data: error.response?.data,
        });

        return Promise.reject(error);
      }
    );

    return client;
  }

  /**
   * Determine if an error is retryable
   */
  private isRetryableError(error: any): boolean {
    // No response means network error (retryable)
    if (!error.response) {
      return true;
    }

    const status = error.response.status;

    // Retry on specific HTTP status codes
    const retryableStatuses = [
      408, // Request Timeout
      429, // Too Many Requests
      500, // Internal Server Error
      502, // Bad Gateway
      503, // Service Unavailable
      504, // Gateway Timeout
    ];

    return retryableStatuses.includes(status);
  }

  /**
   * Delay utility for retry backoff
   */
  private delay(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  /**
   * Helper method to build base Moesif query structure
   */
  private buildMoesifQuery(options: {
    actionName: string;
    size?: number;
    dateRange?: { gte?: string; lte?: string; lt?: string };
    dateField?: string;
    direction?: string;
    additionalFilters?: any[];
  }) {
    const mustConditions: any[] = [
      {
        term: {
          'action_name.raw': options.actionName,
        },
      },
    ];

    // Add date range filter if provided
    if (options.dateRange) {
      const dateFieldName = options.dateField || 'metadata.date';
      mustConditions.push({
        range: {
          [dateFieldName]: options.dateRange,
        },
      });
    }

    // Add direction filter if specified and not 'all'
    if (options.direction && options.direction.toLowerCase() !== 'all') {
      const directionValue =
        options.direction.charAt(0).toUpperCase() + options.direction.slice(1).toLowerCase();
      mustConditions.push({
        term: {
          'metadata.direction.raw': directionValue,
        },
      });
    }

    // Add any additional filters
    if (options.additionalFilters && options.additionalFilters.length > 0) {
      mustConditions.push(...options.additionalFilters);
    }

    const query: any = {
      post_filter: {
        bool: {
          must: mustConditions,
        },
      },
      sort: [{ 'request.time': { order: 'desc' } }],
      _source: ['metadata'],
    };

    // Only add size if it's explicitly provided
    if (options.size !== undefined) {
      query.size = options.size;
    }

    return query;
  }

  /**
   * Helper method to make Moesif API calls
   */
  private async queryMoesif(body: any, queryParams: any = { to: 'now', from: '-52w' }) {
    const response = await this.moesifClient.post(this.moesifSearchPath, body, { params: queryParams });
    return response.data;
  }

  /**
   * Helper method to map Moesif response to MessageDocument
   */
  private mapToMessageDocument(hit: any): MessageDocument {
    const metadata = hit._source.metadata || {};
    return {
      id: metadata.id || '',
      refId: metadata.refId || '',
      mtMessageType: metadata.mtMessageType || '',
      mxMessageType: metadata.mxMessageType || '',
      direction: metadata.direction || '',
      amount: metadata.amount || '',
      currency: metadata.currency || '',
      date: metadata.date || '',
      status: metadata.status || '',
      originalMessage: metadata.originalMessage || '',
      translatedMessage: metadata.translatedMessage || '',
      fieldError: metadata.fieldError || '',
      notSupportedError: metadata.notSupportedError || '',
      invalidError: metadata.invalidError || '',
      otherError: metadata.otherError || '',
    };
  }

  /**
   * Helper method to map Moesif response to LogDocument
   */
  private mapToLogDocument(hit: any): LogDocument {
    const metadata = hit._source.metadata || {};
    return {
      time: metadata.time || '',
      level: metadata.level || '',
      module: metadata.module || '',
      message: metadata.message || '',
    };
  }

  /**
   * Get the total count of actions
   * @returns Total number of actions
   */
  public async getDocumentCount(
    action: string = this.messageActionName
  ): Promise<number> {
    try {
      const actionName = action === this.messageActionName ? this.messageActionName : this.logActionName;
      const body = this.buildMoesifQuery({ actionName, size: 0 });
      const response = await this.queryMoesif(body);
      return response.hits.total || 0;
    } catch (error) {
      throw error;
    }
  }

  /**
   * Get messages within a specified date range with optional direction filtering
   * @param fromDate Start date in ISO format (YYYY-MM-DD)
   * @param toDate End date in ISO format (YYYY-MM-DD)
   * @param direction Optional - 'inward', 'outward', or undefined for all directions
   * @returns Array of messages within the specified date range
   */
  public async getMessagesInDateRange(
    fromDate?: string,
    toDate?: string,
    direction?: string
  ): Promise<MessageDocument[]> {
    try {
      // If no date range is provided, return all messages (with optional direction filter)
      if (!fromDate && !toDate) {
        return this.getAllMessages(direction);
      }

      const count = await this.getDocumentCount();

      const dateRange: any = {};
      if (fromDate) dateRange.gte = fromDate;
      if (toDate) dateRange.lte = toDate;

      const body = this.buildMoesifQuery({
        actionName: this.messageActionName,
        size: count,
        dateRange,
        direction,
      });

      const response = await this.queryMoesif(body);
      return response.hits.hits.map(this.mapToMessageDocument.bind(this));
    } catch (error) {
      return [];
    }
  }

  /**
   * Get logs within a specified date range
   * @param dateFrom Start date in ISO format (YYYY-MM-DD)
   * @param dateTo End date in ISO format (YYYY-MM-DD)
   * @returns Array of logs within the specified date range
   */
  public async getLogData(
    dateFrom?: string,
    dateTo?: string
  ): Promise<LogDocument[]> {
    const now = Date.now();

    try {
      const count = await this.getDocumentCount(this.logActionName);

      // Build date range if provided
      const dateRange: any = {};
      if (dateFrom) {
        dateRange.gte = `${dateFrom}T00:00:00.000Z`;
      }
      if (dateTo) {
        const nextDay = new Date(dateTo);
        nextDay.setDate(nextDay.getDate() + 1);
        const nextDayISO = nextDay.toISOString().split('T')[0];
        dateRange.lt = `${nextDayISO}T00:00:00.000Z`;
      }

      const body = this.buildMoesifQuery({
        actionName: this.logActionName,
        size: count,
        dateRange: Object.keys(dateRange).length > 0 ? dateRange : undefined,
        dateField: 'metadata.time', // Use metadata.time for logs instead of metadata.date
      });

      const response = await this.queryMoesif(body);
      
      const logs = response.hits.hits.map(this.mapToLogDocument.bind(this));

      // Cache the results
      this.cachedLogs = logs;
      this.lastCacheTime = now;

      return logs;
    } catch (error) {
      return [];
    }
  }

  /**
   * Get a single message by ID
   */
  public async getMessageById(id: string) {
    try {
      const body = this.buildMoesifQuery({
        actionName: this.messageActionName,
        size: 1,
        additionalFilters: [
          {
            term: {
              'metadata.id.raw': id,
            },
          },
        ],
      });

      const response = await this.queryMoesif(body);

      const total = response.hits?.total || 0;
      if (total === 0) {
        throw new Error('Message not found');
      }

      return this.mapToMessageDocument(response.hits.hits[0]);
    } catch (error) {
      throw error;
    }
  }

  /**
   * Get chart data for messages by direction and time period
   * @param timeframe 'daily', 'weekly', or 'monthly'
   * @param direction optional - 'inward', 'outward', or undefined for both
   */
  public async getMessageChartData(
    timeframe: 'daily' | 'weekly' | 'monthly',
    direction?: 'inward' | 'outward'
  ) {
    // Get all messages regardless of year
    const allMessages = await this.getAllMessages(direction);

    // Determine date range based on timeframe
    let now = new Date();
    let startDate: Date;

    if (timeframe === 'daily') {
      // For daily view, show past 7 days including today
      startDate = new Date(now);
      startDate.setDate(now.getDate() - 6); // Go back 6 days to include today
      startDate.setHours(0, 0, 0, 0);
    } else if (timeframe === 'weekly') {
      // For weekly view, show past 52 weeks including current week
      startDate = new Date(now);
      startDate.setDate(now.getDate() - 364); // Go back ~52 weeks (364 days)
      startDate.setHours(0, 0, 0, 0);
    } else {
      // For monthly view, show past 12 months including current month
      startDate = new Date(now);
      startDate.setMonth(now.getMonth() - 11); // Go back 11 months to include current month
      startDate.setDate(1); // Start at the 1st of the month
      startDate.setHours(0, 0, 0, 0);
    }

    // Filter by date
    const filteredByDate = allMessages.filter((msg) => {
      const msgDate = new Date(msg.date);
      now.setHours(23, 59, 59, 999); // Set to end of the day
      return msgDate >= startDate && msgDate <= now;
    });

    // Group by time period
    const chartData = new Map();

    // First, create empty data points for all periods to ensure continuous data
    if (timeframe === 'daily') {
      // Create data points for past 7 days including today
      for (let i = 6; i >= 0; i--) {
        const date = new Date(now);
        date.setDate(now.getDate() - i);

        // Format date as YYYY-MM-DD consistently
        const year = date.getFullYear();
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const day = String(date.getDate()).padStart(2, '0');
        const key = `${year}-${month}-${day}`;

        const dayOfWeek = date.getDay(); // 0 = Sunday, 1 = Monday, etc.
        const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

        chartData.set(key, {
          date: key,
          displayDate: `${dayNames[dayOfWeek]} ${month}/${day}`,
          dayOfWeek: dayOfWeek,
          inward: { success: 0, fail: 0 },
          outward: { success: 0, fail: 0 },
        });
      }
    } else if (timeframe === 'weekly') {
      // Create data points for past 52 weeks including current week
      for (let weekOffset = 51; weekOffset >= 0; weekOffset--) {
        // Calculate the date for each week
        const weekDate = new Date(now);
        weekDate.setDate(now.getDate() - weekOffset * 7);

        // Get the week number and year for this date
        const weekYear = weekDate.getFullYear();
        const weekNum = this.getISOWeek(weekDate);

        const key = `${weekYear}-W${String(weekNum).padStart(2, '0')}`;

        // Create a readable display format (Week N, YYYY)
        const displayDate = `Week ${weekNum}, ${weekYear}`;

        chartData.set(key, {
          date: key,
          displayDate,
          weekNumber: weekNum,
          year: weekYear,
          inward: { success: 0, fail: 0 },
          outward: { success: 0, fail: 0 },
        });
      }
    } else {
      // Create data points for past 12 months including current month
      for (let monthOffset = 11; monthOffset >= 0; monthOffset--) {
        const monthDate = new Date(now);
        monthDate.setMonth(now.getMonth() - monthOffset);

        const monthYear = monthDate.getFullYear();
        const month = monthDate.getMonth() + 1;

        const key = `${monthYear}-${String(month).padStart(2, '0')}`;

        // Get month name for display
        const monthNames = [
          'January',
          'February',
          'March',
          'April',
          'May',
          'June',
          'July',
          'August',
          'September',
          'October',
          'November',
          'December',
        ];

        // Create a readable display format (Mon YYYY)
        const displayDate = `${monthNames[month - 1]} ${monthYear}`;

        chartData.set(key, {
          date: key,
          displayDate,
          monthName: monthNames[month - 1],
          year: monthYear,
          inward: { success: 0, fail: 0 },
          outward: { success: 0, fail: 0 },
        });
      }
    }

    // Now populate with actual data
    filteredByDate.forEach((msg) => {
      const msgDate = new Date(msg.date);
      let key: string;

      if (timeframe === 'daily') {
        // Format as YYYY-MM-DD consistently
        const year = msgDate.getFullYear();
        const month = String(msgDate.getMonth() + 1).padStart(2, '0');
        const day = String(msgDate.getDate()).padStart(2, '0');
        key = `${year}-${month}-${day}`;
      } else if (timeframe === 'weekly') {
        // Calculate ISO week number
        const weekNum = this.getISOWeek(msgDate);
        const year = msgDate.getFullYear();
        key = `${year}-W${String(weekNum).padStart(2, '0')}`;
      } else {
        // Format as YYYY-MM
        const year = msgDate.getFullYear();
        const month = String(msgDate.getMonth() + 1).padStart(2, '0');
        key = `${year}-${month}`;
      }

      // Skip if key is not in our pre-defined range
      if (!chartData.has(key)) return;

      // Update counts
      const dataPoint = chartData.get(key);
      const dir = msg.direction.toLowerCase();

      if (msg.status.toLowerCase() === 'successful') {
        dataPoint[dir].success++;
      } else if (msg.status.toLowerCase() === 'failed') {
        dataPoint[dir].fail++;
      }
    });

    // Convert to array and sort by date
    return Array.from(chartData.values()).sort((a, b) => a.date.localeCompare(b.date));
  }

  /**
   * Get all messages from the database or mock data, regardless of year
   */
  public async getAllMessages(
    direction?: string
  ): Promise<MessageDocument[]> {
    const now = Date.now();

    try {
      const count = await this.getDocumentCount();

      const body = this.buildMoesifQuery({
        actionName: this.messageActionName,
        size: count,
        direction,
      });

      const response = await this.queryMoesif(body);
      const messages = response.hits.hits.map(this.mapToMessageDocument.bind(this));

      // Cache the results
      this.cachedMessages = messages;
      this.lastCacheTime = now;

      return messages;
    } catch (error) {
      throw error;
    }
  }

  /**
   * Calculate ISO week number
   * @param date The date to get the week number for
   * @returns Week number (1-53)
   */
  private getISOWeek(date: Date): number {
    const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
    d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay() || 7));
    const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
    return Math.ceil(((d.getTime() - yearStart.getTime()) / 86400000 + 1) / 7);
  }

  /**
   * Get top message types for the specified time period and direction
   * @param timeFilter 'daily', 'weekly', or 'monthly'
   * @param direction optional - 'inward', 'outward', or undefined for both
   * @param limit Number of top message types to return (default: 7)
   * @returns Array of top message types with counts, sorted by frequency
   */
  public async getTopMessageTypes(
    timeFilter: 'daily' | 'weekly' | 'monthly',
    direction?: 'inward' | 'outward',
    limit: number = 7
  ): Promise<{ type: string; count: number }[]> {
    // Get messages for the specified time period
    let messages: MessageDocument[];

    switch (timeFilter) {
      case 'daily':
        messages = await this.getDailyMessages(direction);
        break;
      case 'weekly':
        messages = await this.getWeeklyMessages(direction);
        break;
      case 'monthly':
        messages = await this.getMonthlyMessages(direction);
        break;
      default:
        throw new Error(`Invalid timeFilter: ${timeFilter}`);
    }

    // Apply direction filter if specified
    if (direction) {
      messages = messages.filter((msg) => msg.direction.toLowerCase() === direction.toLowerCase());
    }

    // Count occurrences of each message type
    const typeCounts = new Map<string, number>();

    messages.forEach((msg) => {
      const msgType = msg.mtMessageType || 'Unknown';
      typeCounts.set(msgType, (typeCounts.get(msgType) || 0) + 1);
    });

    // Convert to array and sort by count (descending)
    const sortedTypes = Array.from(typeCounts.entries())
      .map(([type, count]) => ({ type, count }))
      .sort((a, b) => b.count - a.count);

    // Log information about the results
    const directionText = direction ? `${direction} ` : '';

    // Return top N results
    return sortedTypes.slice(0, limit);
  }

  /**
   * Get top message types with more detailed statistics (including success/failure rates)
   * @param timeFilter 'daily', 'weekly', or 'monthly'
   * @param direction optional - 'inward', 'outward', or undefined for both
   * @param limit Number of top message types to return (default: 7)
   * @returns Array of top message types with detailed stats
   */
  public async getTopMessageTypesWithStats(
    timeFilter: 'daily' | 'weekly' | 'monthly',
    direction?: 'inward' | 'outward',
    limit: number = 7
  ): Promise<
    {
      type: string;
      count: number;
      successful: number;
      failed: number;
      successRate: number;
    }[]
  > {
    // Get messages for the specified time period
    let messages: MessageDocument[];

    switch (timeFilter) {
      case 'daily':
        messages = await this.getDailyMessages(direction);
        break;
      case 'weekly':
        messages = await this.getWeeklyMessages(direction);
        break;
      case 'monthly':
        messages = await this.getMonthlyMessages(direction);
        break;
      default:
        throw new Error(`Invalid timeFilter: ${timeFilter}`);
    }

    // Track statistics for each message type
    const typeStats = new Map<
      string,
      {
        count: number;
        successful: number;
        failed: number;
      }
    >();

    messages.forEach((msg) => {
      const msgType = msg.mtMessageType || 'Unknown';

      // Initialize if this is the first time seeing this message type
      if (!typeStats.has(msgType)) {
        typeStats.set(msgType, {
          count: 0,
          successful: 0,
          failed: 0,
        });
      }

      // Update counts
      const stats = typeStats.get(msgType)!;
      stats.count++;

      if (msg.status.toLowerCase() === 'successful') {
        stats.successful++;
      } else if (msg.status.toLowerCase() === 'failed') {
        stats.failed++;
      }
    });

    // Convert to array and compute success rate
    const resultsWithStats = Array.from(typeStats.entries())
      .map(([type, stats]) => ({
        type,
        count: stats.count,
        successful: stats.successful,
        failed: stats.failed,
        successRate: stats.count > 0 ? Math.round((stats.successful / stats.count) * 100) : 0,
      }))
      .sort((a, b) => b.count - a.count);

    // Log information about the results
    const directionText = direction ? `${direction} ` : '';

    // Return top N results
    return resultsWithStats.slice(0, limit);
  }

  /**
   * Force refresh of cached data
   */
  public invalidateCache() {
    this.cachedMessages = null;
    this.lastCacheTime = 0;
  }

  /**
   * Get messages for the current day with optional direction filter
   * @param direction Optional - 'inward', 'outward', or undefined for all directions
   * @returns Array of messages from the current day matching the direction criteria
   */
  public async getDailyMessages(
    direction?: string
  ): Promise<MessageDocument[]> {
    // Get today's date range
    const today = new Date();
    today.setUTCHours(0, 0, 0, 0);

    const endOfToday = new Date(today);
    endOfToday.setUTCHours(23, 59, 59, 999);

    // Format dates for query
    const startDateStr = today.toISOString().split('T')[0];
    const endDateStr = endOfToday.toISOString().split('T')[0];

    try {
      const count = await this.getDocumentCount();

      const body = this.buildMoesifQuery({
        actionName: this.messageActionName,
        size: count,
        dateRange: {
          gte: startDateStr,
          lte: endDateStr,
        },
        direction,
      });

      const response = await this.queryMoesif(body);
      return response.hits.hits.map(this.mapToMessageDocument.bind(this));
    } catch (error) {
      throw error;
    }
  }

  /**
   * Get messages for the current week (Sunday to Saturday) with optional direction filter
   * @param direction Optional - 'inward', 'outward', or undefined for all directions
   * @returns Array of messages from the current week matching the direction criteria
   */
  public async getWeeklyMessages(
    direction?: string
  ): Promise<MessageDocument[]> {
    // Get current week date range
    const today = new Date();

    // Start of week (Monday)
    const startOfWeek = new Date(today);
    const day = today.getDay();
    // Adjust to Monday (1) if today is Sunday (0)
    if (day === 0) {
      startOfWeek.setDate(today.getDate() - 6);
    } else {
      startOfWeek.setDate(today.getDate() - day + 1);
    }
    startOfWeek.setUTCHours(0, 0, 0, 0);

    // End of week (Sunday)
    const endOfWeek = new Date(startOfWeek);
    endOfWeek.setDate(startOfWeek.getDate() + 6);
    endOfWeek.setUTCHours(23, 59, 59, 999);

    // Format dates for query
    const startDateStr = startOfWeek.toISOString().split('T')[0];
    const endDateStr = endOfWeek.toISOString().split('T')[0];

    try {
      const count = await this.getDocumentCount();

      const body = this.buildMoesifQuery({
        actionName: this.messageActionName,
        size: count,
        dateRange: {
          gte: startDateStr,
          lte: endDateStr,
        },
        direction,
      });

      const response = await this.queryMoesif(body);
      return response.hits.hits.map(this.mapToMessageDocument.bind(this));
    } catch (error) {
      throw error;
    }
  }

  /**
   * Get messages for the current month with optional direction filter
   * @param direction Optional - 'inward', 'outward', or undefined for all directions
   * @returns Array of messages from the current month matching the direction criteria
   */
  public async getMonthlyMessages(
    direction?: string
  ): Promise<MessageDocument[]> {
    // Get current month date range
    const today = new Date();

    // Start of month
    const startOfMonth = new Date(today.getFullYear(), today.getMonth(), 2); // Changed from 2 to 1 to include the 1st day
    startOfMonth.setHours(0, 0, 0, 0);

    // End of month
    const endOfMonth = new Date(today.getFullYear(), today.getMonth() + 1, 0);
    endOfMonth.setHours(23, 59, 59, 999);

    // Format dates for query
    const startDateStr = startOfMonth.toISOString().split('T')[0];
    const endDateStr = endOfMonth.toISOString().split('T')[0];

    try {
      const count = await this.getDocumentCount();

      const body = this.buildMoesifQuery({
        actionName: this.messageActionName,
        size: count,
        dateRange: {
          gte: startDateStr,
          lte: endDateStr,
        },
        direction,
      });

      const response = await this.queryMoesif(body);
      return response.hits.hits.map(this.mapToMessageDocument.bind(this));
    } catch (error) {
      throw error;
    }
  }

  /**
   * Get chart data for daily messages
   * @param direction optional - 'inward', 'outward', or undefined for both
   */
  public async getDailyChartData(direction?: 'inward' | 'outward') {
    // Get messages for the current day
    const messages = await this.getDailyMessages(direction);

    // Create data points for each hour of the day (0-23)
    const hourlyData = new Map();

    // Pre-populate hours
    for (let hour = 0; hour < 24; hour++) {
      const key = hour.toString().padStart(2, '0');
      hourlyData.set(key, {
        hour: key,
        inward: { success: 0, fail: 0 },
        outward: { success: 0, fail: 0 },
      });
    }

    // Populate with message data
    messages.forEach((msg) => {
      const msgDate = new Date(msg.date);
      const hour = msgDate.getHours().toString().padStart(2, '0');

      if (!hourlyData.has(hour)) return;

      const dataPoint = hourlyData.get(hour);
      const dir = msg.direction.toLowerCase();

      if (msg.status.toLowerCase() === 'successful') {
        dataPoint[dir].success++;
      } else if (msg.status.toLowerCase() === 'failed') {
        dataPoint[dir].fail++;
      }
    });

    // Convert to array and sort by hour
    return Array.from(hourlyData.values());
  }

  /**
   * Get chart data for weekly messages
   * @param direction optional - 'inward', 'outward', or undefined for both
   */
  public async getWeeklyChartData(direction?: 'inward' | 'outward') {
    // Get messages for the current week
    const messages = await this.getWeeklyMessages(direction);

    // Create data points for each day of the week (Sunday to Saturday)
    const dailyData = new Map();
    const today = new Date();

    // Pre-populate days of the week
    const startOfWeek = new Date(today);
    startOfWeek.setDate(today.getDate() - today.getDay()); // Sunday
    startOfWeek.setHours(0, 0, 0, 0);

    for (let i = 0; i < 7; i++) {
      const date = new Date(startOfWeek);
      date.setDate(startOfWeek.getDate() + i);

      const year = date.getFullYear();
      const month = String(date.getMonth() + 1).padStart(2, '0');
      const day = String(date.getDate()).padStart(2, '0');
      const key = `${year}-${month}-${day}`;

      dailyData.set(key, {
        date: key,
        dayName: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][i],
        dayOfWeek: i,
        inward: { success: 0, fail: 0 },
        outward: { success: 0, fail: 0 },
      });
    }

    // Populate with message data
    messages.forEach((msg) => {
      const msgDate = new Date(msg.date);
      const year = msgDate.getFullYear();
      const month = String(msgDate.getMonth() + 1).padStart(2, '0');
      const day = String(msgDate.getDate()).padStart(2, '0');
      const key = `${year}-${month}-${day}`;

      if (!dailyData.has(key)) return;

      const dataPoint = dailyData.get(key);
      const dir = msg.direction.toLowerCase();

      if (msg.status.toLowerCase() === 'successful') {
        dataPoint[dir].success++;
      } else if (msg.status.toLowerCase() === 'failed') {
        dataPoint[dir].fail++;
      }
    });

    // Convert to array and sort by day of week
    return Array.from(dailyData.values()).sort((a, b) => a.dayOfWeek - b.dayOfWeek);
  }

  /**
   * Get chart data for monthly messages
   * @param direction optional - 'inward', 'outward', or undefined for both
   */
  public async getMonthlyChartData(direction?: 'inward' | 'outward') {
    // Get messages for the current month
    const messages = await this.getMonthlyMessages(direction);

    // Create data points for each day of the month
    const dailyData = new Map();
    const today = new Date();

    // Pre-populate days of the month
    const daysInMonth = new Date(today.getFullYear(), today.getMonth() + 1, 0).getDate();
    const startOfMonth = new Date(today.getFullYear(), today.getMonth(), 1);

    for (let i = 0; i < daysInMonth; i++) {
      const date = new Date(startOfMonth);
      date.setDate(startOfMonth.getDate() + i);

      const year = date.getFullYear();
      const month = String(date.getMonth() + 1).padStart(2, '0');
      const day = String(date.getDate()).padStart(2, '0');
      const key = `${year}-${month}-${day}`;

      dailyData.set(key, {
        date: key,
        day: date.getDate(),
        inward: { success: 0, fail: 0 },
        outward: { success: 0, fail: 0 },
      });
    }

    // Populate with message data
    messages.forEach((msg) => {
      const msgDate = new Date(msg.date);
      const year = msgDate.getFullYear();
      const month = String(msgDate.getMonth() + 1).padStart(2, '0');
      const day = String(msgDate.getDate()).padStart(2, '0');
      const key = `${year}-${month}-${day}`;

      if (!dailyData.has(key)) return;

      const dataPoint = dailyData.get(key);
      const dir = msg.direction.toLowerCase();

      if (msg.status.toLowerCase() === 'successful') {
        dataPoint[dir].success++;
      } else if (msg.status.toLowerCase() === 'failed') {
        dataPoint[dir].fail++;
      }
    });

    // Convert to array and sort by date
    return Array.from(dailyData.values()).sort((a, b) => a.date.localeCompare(b.date));
  }

  /**
   * Get the most recent messages with essential details
   * @param limit Number of messages to return (default: 5)
   * @param direction Filter by message direction ('All', 'Inward', or 'Outward')
   * @param period Filter by time period ('Daily', 'Weekly', 'Monthly')
   * @returns Array of recent messages with id, time, message type and status
   */
  public async getRecentMessages(
    limit: number = 5,
    direction: string = 'All',
    period: string = 'All'
  ): Promise<
    {
      id: string;
      refId: string;
      time: string;
      mtMessageType: string;
      status: string;
      direction: string;
    }[]
  > {
    try {
      let timeFilteredMessages: MessageDocument[];
      if (period === 'Daily') {
        // Filter to messages from today only
        timeFilteredMessages = await this.getDailyMessages();
      } else if (period === 'Weekly') {
        // Filter to messages from the current week
        timeFilteredMessages = await this.getWeeklyMessages();
      } else {
        timeFilteredMessages = await this.getMonthlyMessages();
      }

      // Filter by direction if not 'All'
      let filteredMessages = timeFilteredMessages;
      if (direction && direction !== 'All') {
        filteredMessages = timeFilteredMessages.filter(
          (msg) => msg.direction.toLowerCase() === direction.toLowerCase()
        );
      }

      // Sort by date (most recent first)
      const sortedMessages = [...filteredMessages].sort((a, b) => {
        return new Date(b.date).getTime() - new Date(a.date).getTime();
      });

      // Take the top N messages and format the response
      const recentMessages = sortedMessages.slice(0, limit).map((msg) => {
        // Parse the date to format a datetime string
        const messageDate = new Date(msg.date);

        // Format the date as YYYY-MM-DD HH:MM
        const year = messageDate.getFullYear();
        const month = String(messageDate.getMonth() + 1).padStart(2, '0');
        const day = String(messageDate.getDate()).padStart(2, '0');
        const hours = messageDate.getHours().toString().padStart(2, '0');
        const minutes = messageDate.getMinutes().toString().padStart(2, '0');

        // Create datetime string in format: "YYYY-MM-DD HH:MM"
        const time = `${year}-${month}-${day}T${hours}:${minutes}`;

        return {
          id: msg.id,
          refId: msg.refId,
          time,
          mtMessageType: msg.mtMessageType,
          status: msg.status,
          direction: msg.direction,
        };
      });

      // Log summary of applied filters
      let filterDesc = '';
      if (period !== 'All') filterDesc += ` for ${period.toLowerCase()} period`;
      if (direction !== 'All') filterDesc += ` with ${direction} direction`;
      return recentMessages;
    } catch (error) {
      throw error;
    }
  }

  /**
   * Get error statistics categorized by error type
   * @param timeFilter 'daily', 'weekly', 'monthly', or 'all'
   * @param direction 'inward', 'outward', or 'all'
   * @returns Object containing counts of different error types
   */
  public async getErrorStatistics(
    timeFilter: string,
    direction: string
  ): Promise<{
    fieldErrors: number;
    notSupportedErrors: number;
    invalidErrors: number;
    otherErrors: number;
    totalErrors: number;
  }> {
    try {
      // Get messages for the specified time period
      let messages: MessageDocument[];

      switch (timeFilter) {
        case 'Daily':
          messages = await this.getDailyMessages();
          break;
        case 'Weekly':
          messages = await this.getWeeklyMessages();
          break;
        default:
          messages = await this.getMonthlyMessages();
          break;
      }

      // Apply direction filter if specified and not 'all'
      if (direction !== 'All') {
        messages = messages.filter(
          (msg) => msg.direction.toLowerCase() === direction.toLowerCase()
        );
      }

      // Filter to only failed messages
      const failedMessages = messages.filter((msg) => msg.status.toLowerCase() === 'failed');

      // Count different error types
      const fieldErrors = failedMessages.filter(
        (msg) => msg.fieldError && msg.fieldError.trim() !== ''
      ).length;
      const notSupportedErrors = failedMessages.filter(
        (msg) => msg.notSupportedError && msg.notSupportedError.trim() !== ''
      ).length;
      const invalidErrors = failedMessages.filter(
        (msg) => msg.invalidError && msg.invalidError.trim() !== ''
      ).length;
      const otherErrors = failedMessages.filter(
        (msg) =>
          (msg.otherError && msg.otherError.trim() !== '') ||
          ((!msg.fieldError || msg.fieldError.trim() === '') &&
            (!msg.notSupportedError || msg.notSupportedError.trim() === '') &&
            (!msg.invalidError || msg.invalidError.trim() === ''))
      ).length;

      // Build result
      const result = {
        fieldErrors,
        notSupportedErrors,
        invalidErrors,
        otherErrors,
        totalErrors: failedMessages.length,
      };

      // Log summary
      let filterDesc = '';
      if (timeFilter !== 'All') filterDesc += ` for ${timeFilter} period`;
      if (direction !== 'All') filterDesc += ` with ${direction} direction`;

      return result;
    } catch (error) {
      throw error;
    }
  }
}

// Extend Axios request config to include retry metadata
interface AxiosRequestConfigWithMetadata extends InternalAxiosRequestConfig {
  metadata?: {
    startTime?: number;
    retryCount: number;
  };
}

export default MoesifService;
