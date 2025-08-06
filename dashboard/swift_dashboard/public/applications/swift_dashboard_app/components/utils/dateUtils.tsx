/**
 * Gets the ISO week number for a given date
 * @param date The date to get the week number for
 * @returns The ISO week number (1-53)
 */
export const getISOWeek = (date: Date): number => {
    const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
    d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay() || 7));
    const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
    return Math.ceil(((d.getTime() - yearStart.getTime()) / 86400000 + 1) / 7);
  };
  
  /**
   * Gets the current week number
   * @returns The current ISO week number (1-53)
   */
  export const getCurrentWeekNumber = (): number => {
    return getISOWeek(new Date());
  };
  
  /**
   * Parse ISO week string into a date object representing the first day of that week
   * @param weekString String in format "YYYY-Wnn" (e.g., "2025-W13")
   * @returns Date object for first day of that week
   */
  export const parseISOWeek = (weekString: string): Date => {
    const [year, weekPart] = weekString.split('-W');
    const weekNum = parseInt(weekPart, 10);
    
    // Find first day of year
    const firstDayOfYear = new Date(parseInt(year, 10), 0, 1);
    
    // Find day of week for Jan 1
    const dayOfWeek = firstDayOfYear.getDay();
    
    // Find first Thursday of year (ISO weeks start with Monday and include Thursday)
    const firstThursday = new Date(parseInt(year, 10), 0, 1 + ((11 - dayOfWeek) % 7));
    
    // Go back to Monday
    const firstMonday = new Date(firstThursday);
    firstMonday.setDate(firstThursday.getDate() - 3);
    
    // Add weeks
    const result = new Date(firstMonday);
    result.setDate(firstMonday.getDate() + (weekNum - 1) * 7);
    
    return result;
  };

  /**
 * Date utility functions for consistent date handling across the application
 */

/**
 * Get start and end of the current day in UTC
 * @returns Object with startOfDay, endOfDay, startDateStr and endDateStr
 */
export function getDayRange(): {
    startOfDay: Date;
    endOfDay: Date;
    startDateStr: string;
    endDateStr: string;
  } {
    const today = new Date();
    today.setUTCHours(0, 0, 0, 0);
    
    const endOfToday = new Date(today);
    endOfToday.setUTCHours(23, 59, 59, 999);
    
    const startDateStr = today.toISOString().split('T')[0];
    console.log('startDateStr', startDateStr);
    const endDateStr = endOfToday.toISOString().split('T')[0];
    
    return {
      startOfDay: today,
      endOfDay: endOfToday,
      startDateStr,
      endDateStr
    };
  }
  
  /**
   * Get start and end of the current week in UTC (Monday to Sunday)
   * @returns Object with startOfWeek, endOfWeek, startDateStr and endDateStr
   */
  export function getWeekRange(): {
    startOfWeek: Date;
    endOfWeek: Date;
    startDateStr: string;
    endDateStr: string;
  } {
    const today = new Date();
    
    // Start of week (Sunday)
    const startOfWeek = new Date(today);
    const day = today.getDay();
    // Adjust to Monday (1) if today is Sunday (0)
    if (day === 0) {
      startOfWeek.setDate(today.getDate() - 6);
    } else {
      startOfWeek.setDate(today.getDate() - day + 1);
    }
    startOfWeek.setUTCHours(0, 0, 0, 0);
    startOfWeek.setUTCHours(0, 0, 0, 0);
    
    // End of week (Saturday)
    const endOfWeek = new Date(startOfWeek);
    endOfWeek.setDate(startOfWeek.getDate() + 6);
    endOfWeek.setUTCHours(23, 59, 59, 999);
    
    // Format dates for query
    const startDateStr = startOfWeek.toISOString().split('T')[0];
    console.log('startDateStr', startDateStr);
    const endDateStr = endOfWeek.toISOString().split('T')[0];
    
    return {
      startOfWeek,
      endOfWeek,
      startDateStr,
      endDateStr
    };
  }
  
  /**
   * Get start and end of the current month in UTC
   * @returns Object with startOfMonth, endOfMonth, startDateStr and endDateStr
   */
  export function getMonthRange(): {
    startOfMonth: Date;
    endOfMonth: Date;
    startDateStr: string;
    endDateStr: string;
  } {
    const today = new Date();
    
    // Start of month
    const startOfMonth = new Date(today.getFullYear(), today.getMonth(), 2);
    startOfMonth.setHours(0, 0, 0, 0);
    
    // End of month
    const endOfMonth = new Date(today.getFullYear(), today.getMonth() + 1, 0);
    endOfMonth.setHours(23, 59, 59, 999);
    
    // Format dates for query
    const startDateStr = startOfMonth.toISOString().split('T')[0];
    console.log('startDateStr', startDateStr);
    const endDateStr = endOfMonth.toISOString().split('T')[0];
    
    return {
      startOfMonth,
      endOfMonth,
      startDateStr,
      endDateStr
    };
  }
  
  /**
   * Get date range for a specific time period
   * @param period 'daily', 'weekly', 'monthly' or 'all'
   * @returns Object with start date, end date, and formatted date strings
   */
  export function getDateRangeForPeriod(period: string): {
    startDate: Date;
    endDate: Date;
    startDateStr: string;
    endDateStr: string;
  } {
    switch(period.toLowerCase()) {
      case 'daily':
        const dayRange = getDayRange();
        return {
          startDate: dayRange.startOfDay,
          endDate: dayRange.endOfDay,
          startDateStr: dayRange.startDateStr,
          endDateStr: dayRange.endDateStr
        };
      case 'weekly':
        const weekRange = getWeekRange();
        return {
          startDate: weekRange.startOfWeek,
          endDate: weekRange.endOfWeek,
          startDateStr: weekRange.startDateStr,
          endDateStr: weekRange.endDateStr
        };
      case 'monthly':
        const monthRange = getMonthRange();
        return {
          startDate: monthRange.startOfMonth,
          endDate: monthRange.endOfMonth,
          startDateStr: monthRange.startDateStr,
          endDateStr: monthRange.endDateStr
        };
      default:
        // For 'all', use a very wide range
        const startDate = new Date(2000, 0, 1);
        const endDate = new Date();
        endDate.setUTCHours(23, 59, 59, 999);
        
        return {
          startDate,
          endDate,
          startDateStr: startDate.toISOString().split('T')[0],
          endDateStr: endDate.toISOString().split('T')[0]
        };
    }
  }
  
  /**
   * Format a date as YYYY-MM-DD
   * @param date Date to format
   * @returns Formatted date string
   */
  export function formatDateString(date: Date): string {
    return date.toISOString().split('T')[0];
  }
  
  /**
   * Format a date and time for display (YYYY-MM-DD HH:MM)
   * @param date Date to format
   * @returns Formatted date-time string
   */
  export function formatDateTime(date: Date): string {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    const hours = String(date.getHours()).padStart(2, '0');
    const minutes = String(date.getMinutes()).padStart(2, '0');
    
    return `${year}-${month}-${day}T${hours}:${minutes}`;
  }
  
  /**
   * Get month name from month number (0-11)
   * @param monthNumber Month number (0-11)
   * @returns Month name
   */
  export function getMonthName(monthNumber: number): string {
    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    
    return monthNames[monthNumber];
  }
  
  /**
   * Check if two dates are the same day
   * @param date1 First date
   * @param date2 Second date
   * @returns True if dates are the same day
   */
  export function isSameDay(date1: Date, date2: Date): boolean {
    return date1.getUTCFullYear() === date2.getUTCFullYear() &&
      date1.getUTCMonth() === date2.getUTCMonth() &&
      date1.getUTCDate() === date2.getUTCDate();
  }
  
  /**
   * Check if a date is within the specified date range
   * @param date Date to check
   * @param startDate Range start date
   * @param endDate Range end date
   * @returns True if date is within range
   */
  export function isDateInRange(date: Date, startDate: Date, endDate: Date): boolean {
    return date >= startDate && date <= endDate;
  }
  