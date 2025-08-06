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

import React, { useState, useEffect, useCallback, memo, useRef } from 'react';
import { withRouter } from 'react-router-dom';
import './MessagesPage.scss';
import Table from './Table/Table';
import Button from './BackButton/BackButton';
import MessagePanel from './MessagePanels/MessagePanel';
import { MessageData } from './types';
import apiService from '../../../services';
import {getDateRangeForPeriod, getMonthRange} from './utils/dateUtils';
import Pagination from './Pagination';
import './commonStyles.scss';
// Define TableFilters interface (matches the structure in your Table component)
export interface TableFilters {
    id: string;
    mtMessageType: string;
    mxMessageType: string;
    direction: string;
    amountMin: string;
    amountMax: string;
    currency: string;
    dateFrom: string;  
    dateTo: string;   
    status: string;
    errorType?: string;
    timeFilter?: string;
}

// Define the type for location.state
interface LocationState {
    selectedMessageId?: string;
    showDetails?: boolean;
    filters?: {
        timeFilter: string;
        status?: string;
        direction?: string;
        errorType?: string;
    };
}


// Create a carefully memoized version of the Table component
const MemoizedTable = memo(Table, (prevProps, nextProps) => {
    // Always re-render if filters change
    if (prevProps.filters !== nextProps.filters) return false;
    
    // Always re-render if data length changes
    if (prevProps.data.length !== nextProps.data.length) return false;
    
    // Otherwise, re-render only if data content changes
    return JSON.stringify(prevProps.data) === JSON.stringify(nextProps.data);
});

// Add this function before the MessagesPage component declaration
/**
 * Normalizes message data to ensure consistent structure
 * @param message Raw message data from API
 * @returns Normalized message with consistent structure and defaults
 */
const normalizeMessage = (message: any): MessageData => {
    return {
      id: message.id || '',
      mtMessageType: message.mtMessageType || '',
      mxMessageType: message.mxMessageType || '',
      currency: message.currency || '',
      amount: message.amount?.toString() || '0',
      date: message.date || '',
      direction: message.direction || '',
      status: message.status || '',
      originalMessage: message.originalMessage || '',
      translatedMessage: message.translatedMessage || '',
      fieldError: message.fieldError || '',
      notSupportedError: message.notSupportedError || '',
      invalidError: message.invalidError || '',
      otherError: message.otherError || ''
    };
};

const MessagesPage: React.FC<{ location: any }> = ({ location }) => {
    const [selectedMessage, setSelectedMessage] = useState<MessageData | null>(null);
    const [messages, setMessages] = useState<MessageData[]>([]);
    const [loading, setLoading] = useState<boolean>(true);
    const [error, setError] = useState<string | null>(null);
    const [detailsLoading, setDetailsLoading] = useState<boolean>(false);
    const [specialFilters, setSpecialFilters] = useState({
        errorType: '',
        timeFilter: ''
    });
    
    // Pagination state
    const [currentPage, setCurrentPage] = useState<number>(1);
    const [pageSize, setPageSize] = useState<number>(10); // Default 10 items per page
    const pageSizeOptions = [10, 25, 50, 100];
    
    // Force component updates when filters change
    const [forceUpdate, setForceUpdate] = useState<number>(0);

    const month = getMonthRange();
    
    // Store the applied table filters that are actually used for filtering
    const [tableFilters, setTableFilters] = useState<TableFilters>({
        id: '',
        mtMessageType: '',
        mxMessageType: '',
        direction: '',
        amountMin: '',
        amountMax: '',
        currency: '',
        dateFrom: month.startDateStr, // Default to the start of the current month
        dateTo: month.endDateStr, // Default to the end of the current month
        status: ''
    });
    
    const [pendingFilters, setPendingFilters] = useState<TableFilters>({
        id: '',
        mtMessageType: '',
        mxMessageType: '',
        direction: '',
        amountMin: '',
        amountMax: '',
        currency: '',
        dateFrom: month.startDateStr, 
        dateTo: month.endDateStr,    
        status: ''
    });

    // Apply filters from the navigation state if available
    useEffect(() => {
        const state = location.state as LocationState;
        if (state && state.filters) {
            const navFilters = state.filters;
            
            const dateRange = getDateRangeForPeriod(navFilters.timeFilter);
            // Create new filters object with navigation state
            const newFilters = {
                ...pendingFilters,
                dateFrom: dateRange?.startDateStr || '',
                dateTo: dateRange?.endDateStr || '',
                status: navFilters.status || '',
                direction: navFilters.direction || '',
            };
            

            // Apply the filters immediately
            setPendingFilters(newFilters);
            setTableFilters(newFilters);
            
            // Store any special filters that aren't visible in table columns
            setSpecialFilters({
                errorType: navFilters.errorType || '',
                timeFilter: navFilters.timeFilter || ''
            });
            
            // Reset to first page when filters change via navigation
            setCurrentPage(1);
            
            // Force a re-render to apply filters
            setForceUpdate(prev => prev + 1);
        }
    }, [location]);

    // Fetch all messages when component mounts
    useEffect(() => {
        const fetchMessages = async () => {
            try {
                setLoading(true);
                const data = await apiService.getAllMessages(tableFilters.dateFrom, tableFilters.dateTo, tableFilters.direction);
                
                // Normalize data to ensure consistent structure
                const normalizedData = data.map(normalizeMessage);
                
                setMessages(normalizedData);
                setError(null);
            } catch (err) {
                setError('Failed to load messages. Please try again later.');
            } finally {
                setLoading(false);
            }
        };

        fetchMessages();
    }, []);

    // Check for navigation state on component mount
    useEffect(() => {
        const fetchSelectedMessage = async () => {
            const state = location.state as LocationState;
            if (state && state.selectedMessageId && state.showDetails) {
                try {
                    setDetailsLoading(true);
                    const message = await apiService.getMessageById(state.selectedMessageId);
                    
                    if (message) {
                        // Normalize the selected message
                        const normalizedMessage = normalizeMessage(message);
                        
                        setSelectedMessage(normalizedMessage);
                    } else {
                        setError('Selected message not found.');
                    }
                } catch (err) {
                    setError('Failed to load the selected message details.');
                } finally {
                    setDetailsLoading(false);
                }
            }
        };

        fetchSelectedMessage();
    }, [location]);

    // This handler will be passed to the Table component - memoize it to prevent unnecessary re-renders
    const handleRowClick = useCallback(async (id: string) => {
        try {
            setDetailsLoading(true);
            const message = await apiService.getMessageById(id);
            
            if (message) {
                // Normalize the selected message
                const normalizedMessage = normalizeMessage(message);
                
                setSelectedMessage(normalizedMessage);
                setError(null);
            } else {
                setError('Message not found.');
            }
        } catch (err) {
            setError('Failed to load message details.');
        } finally {
            setDetailsLoading(false);
        }
    }, []);
  
    const handleBackClick = useCallback(() => {
        setSelectedMessage(null);
    }, []);
    
    // Handler for filter changes - updates only the pending filters
    const handleFilterChange = useCallback((newFilters: TableFilters) => {
        setPendingFilters(newFilters);
    }, []);
    
    // Handler to apply filters
    const handleApplyFilters = useCallback(async () => {
        setTableFilters(pendingFilters);

        const data = await apiService.getAllMessages(pendingFilters.dateFrom, pendingFilters.dateTo, pendingFilters.direction);

        // Normalize data to ensure consistent structure
        const normalizedData = data.map(normalizeMessage);

        setMessages(normalizedData);

        // Reset to first page when filters are applied
        setCurrentPage(1);
        // Force a re-render when filters are applied
        setForceUpdate(prev => prev + 1);
    }, [pendingFilters]);
    
    // Handler to clear all filters
    const handleClearFilters = useCallback(async () => {
        const emptyFilters = {
            id: '',
            mtMessageType: '',
            mxMessageType: '',
            direction: '',
            amountMin: '',
            amountMax: '',
            currency: '',
            dateFrom: '',
            dateTo: '',
            status: ''
        };
        
        const data = await apiService.getAllMessages();

        // Normalize data to ensure consistent structure
        const normalizedData = data.map(normalizeMessage);

        setMessages(normalizedData);

        setPendingFilters(emptyFilters);
        setTableFilters(emptyFilters);
        // Reset to first page when clearing filters
        setCurrentPage(1);
        // Also clear special filters
        setSpecialFilters({
            errorType: '',
            timeFilter: ''
        });
        // Force a re-render when clearing filters
        setForceUpdate(prev => prev + 1);
    }, []);
    
    // Pagination handlers
    const handlePageChange = useCallback((page: number) => {
        setCurrentPage(page);
        // Scroll to top of the table when page changes
        window.scrollTo({
            top: document.querySelector(`.container`)?.getBoundingClientRect().top 
                ? window.scrollY + (document.querySelector(`.container`)?.getBoundingClientRect().top || 0) - 20
                : 0,
            behavior: 'smooth'
        });
    }, []);
    
    const handlePageSizeChange = useCallback((newSize: number) => {
        setPageSize(newSize);
        setCurrentPage(1); // Reset to first page when changing page size
    }, []);
    
    // Filter the messages based on all filters
    const filteredMessages = React.useMemo(() => {
        // Check if there are any regular filters or special filters applied
        if (Object.values(tableFilters).every(v => !v) && !specialFilters.errorType && !specialFilters.timeFilter) {
            return messages; // No filters applied, return all messages
        }
        
        return messages.filter(item => {
            try {
                // Safely access properties with fallbacks
                const itemId = item.id?.toString().toLowerCase() || '';
                const itemMtType = item.mtMessageType?.toString().toLowerCase() || '';
                const itemMxType = item.mxMessageType?.toString().toLowerCase() || '';
                const itemDirection = item.direction || '';
                const itemCurrency = item.currency?.toString().toLowerCase() || '';
                const itemDate = item.date || '';
                const itemStatus = item.status || '';
                
                // Parse amount as number safely
                let itemAmount = 0;
                try {
                    const amountString = item.amount?.toString().replace(/[^\d.-]/g, '') || '0';
                    itemAmount = parseFloat(amountString);
                    if (isNaN(itemAmount)) itemAmount = 0;
                } catch (error) {
                    itemAmount = 0;
                }
                
                // Now apply the filters
                const meetsIdFilter = !tableFilters.id || itemId.includes(tableFilters.id.toLowerCase());
                const meetsMtTypeFilter = !tableFilters.mtMessageType || itemMtType.includes(tableFilters.mtMessageType.toLowerCase());
                const meetsMxTypeFilter = !tableFilters.mxMessageType || itemMxType.includes(tableFilters.mxMessageType.toLowerCase());
                const meetsDirectionFilter = !tableFilters.direction || itemDirection === tableFilters.direction;
                
                const meetsMinAmountFilter = !tableFilters.amountMin || 
                    (itemAmount && !isNaN(itemAmount) && itemAmount >= parseFloat(tableFilters.amountMin));
                    
                const meetsMaxAmountFilter = !tableFilters.amountMax || 
                    (itemAmount && !isNaN(itemAmount) && itemAmount <= parseFloat(tableFilters.amountMax));
                    
                const meetsCurrencyFilter = !tableFilters.currency || itemCurrency.includes(tableFilters.currency.toLowerCase());
                
                const meetsDateFilter = (() => {
                    // If no date filters are set, all dates pass
                    if (!tableFilters.dateFrom && !tableFilters.dateTo) return true;
                    
                    // If item has no date, it fails date filtering
                    if (!itemDate) return false;
                    
                    try {
                        // Parse the item date once
                        const itemDateTime = new Date(itemDate);
                        
                        // Set to start of day to avoid time comparison issues
                        const itemDateNormalized = new Date(
                            itemDateTime.getFullYear(),
                            itemDateTime.getMonth(),
                            itemDateTime.getDate()
                        );
                        
                        // Check from date if specified
                        if (tableFilters.dateFrom) {
                            const fromDate = new Date(tableFilters.dateFrom);
                            const fromDateNormalized = new Date(
                                fromDate.getFullYear(),
                                fromDate.getMonth(), 
                                fromDate.getDate()
                            );
                            
                            if (itemDateNormalized < fromDateNormalized) return false;
                        }

                        // Check to date if specified (including the entire day)
                        if (tableFilters.dateTo) {
                            const toDate = new Date(tableFilters.dateTo);
                            const toDateNormalized = new Date(
                                toDate.getFullYear(),
                                toDate.getMonth(),
                                toDate.getDate(),
                                23, 59, 59 // Set to end of day
                            );
                            
                            if (itemDateNormalized > toDateNormalized) return false;
                        }
                        
                        return true;
                    } catch (error) {
                        return false;
                    }
                })();
                    
                const meetsStatusFilter = !tableFilters.status || itemStatus === tableFilters.status;
                
                // Special filter handling for time period
                const meetsErrorFilter = (() => {
                    if (specialFilters.errorType !== '') {
                        switch (specialFilters.errorType) {
                            case 'fieldError':
                                return item.fieldError !== '';
                            case 'notSupportedError':
                                return item.notSupportedError !== '';
                            case 'invalidError':
                                return item.invalidError !== '';
                            case 'otherError':
                                return item.otherError !== '';              
                            default:
                                return false;   
                        }
                    }
                    return true;
                })();
            
                return (
                    meetsIdFilter && 
                    meetsMtTypeFilter && 
                    meetsMxTypeFilter && 
                    meetsDirectionFilter && 
                    meetsMinAmountFilter && 
                    meetsMaxAmountFilter && 
                    meetsCurrencyFilter && 
                    meetsDateFilter && 
                    meetsStatusFilter &&
                    meetsErrorFilter
                );
            } catch (error) {
                return false;
            }
        });
    }, [messages, tableFilters, specialFilters]);
    
    // Calculate paginated messages from filtered messages
    const paginatedMessages = React.useMemo(() => {
        const startIndex = (currentPage - 1) * pageSize;
        return filteredMessages.slice(startIndex, startIndex + pageSize);
    }, [filteredMessages, currentPage, pageSize]);
    
    // Calculate total number of pages
    const totalPages = React.useMemo(() => {
        return Math.max(1, Math.ceil(filteredMessages.length / pageSize));
    }, [filteredMessages.length, pageSize]);
  
    return (
        <div className='container'>
            <h2>Messages List</h2>
            
            {selectedMessage ? (
                <div className='detailView'>
                    {/* Show just the selected row */}
                    <div className='singleRow'>
                        <MemoizedTable 
                            data={[selectedMessage]} 
                            onRowClick={() => {}}
                            // Pass filters but disable the filter inputs in detail view
                            filters={pendingFilters}
                            onFilterChange={handleFilterChange}
                            disableFilters={true}
                            forceRender={forceUpdate} // Add a key to force re-render
                        />
                    </div>
                    
                    <Button onClick={handleBackClick} data={'Back to All Messages'}></Button>
                    
                    {detailsLoading ? (
                        <div className='loadingIndicator'>
                            <div className='spinner'></div>
                            <span>Loading message details...</span>
                        </div>
                    ) : (
                        <div className='messagePanels'>
                            <MessagePanel
                                title="Original Message" 
                                message={selectedMessage.originalMessage}/>
                            
                            <MessagePanel 
                                title="Translated Message"
                                message={selectedMessage.translatedMessage ? selectedMessage.translatedMessage : 
                                    selectedMessage.fieldError ? selectedMessage.fieldError : 
                                    selectedMessage.notSupportedError ? selectedMessage.notSupportedError : 
                                    selectedMessage.invalidError ? selectedMessage.invalidError : selectedMessage.otherError}/>
                        </div>
                    )}
                </div>
            ) : (
                <div>
                    {loading ? (
                        <div className='loadingIndicator'>
                            <div className='spinner'></div>
                            <span>Loading messages...</span>
                        </div>
                    ) : error ? (
                        <div className='error'>{error}</div>
                    ) : (
                        <>
                            <div className='filterButtons'>
                                <button 
                                    onClick={handleApplyFilters}
                                    className='applyFiltersBtn'
                                    disabled={JSON.stringify(pendingFilters) === JSON.stringify(tableFilters)}
                                >
                                    Apply Filters
                                </button>
                                <button 
                                    onClick={handleClearFilters}
                                    className='clearFiltersBtn'
                                    disabled={!Object.values(tableFilters).some(v => v !== '')}
                                >
                                    Clear All Filters
                                </button>
                            </div>
                            
                            {/* Pass the paginated messages instead of all filtered messages */}
                            <Table 
                                data={paginatedMessages} 
                                onRowClick={handleRowClick} 
                                filters={pendingFilters}
                                onFilterChange={handleFilterChange}
                                key={forceUpdate} // Force re-render with key
                            />
                            
                            {/* Pagination below table */}
                            {filteredMessages.length > 0 && (
                                <Pagination
                                    currentPage={currentPage}
                                    totalPages={totalPages}
                                    pageSize={pageSize}
                                    pageSizeOptions={pageSizeOptions}
                                    onPageChange={handlePageChange}
                                    onPageSizeChange={handlePageSizeChange}
                                    totalItems={filteredMessages.length}
                                />
                            )}
                            
                            {detailsLoading && (
                                <div className='overlay'>
                                    <div className='spinner'></div>
                                    <span>Loading message details...</span>
                                </div>
                            )}
                        </>
                    )}
                </div>
            )}
        </div>
    );
};

export default withRouter(MessagesPage);
