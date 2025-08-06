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

import React from 'react';
import './Pagination.scss';
import './commonStyles.scss';

interface PaginationProps {
  currentPage: number;
  totalPages: number;
  pageSize: number;
  pageSizeOptions: number[];
  onPageChange: (page: number) => void;
  onPageSizeChange: (pageSize: number) => void;
  totalItems: number;
}

const Pagination: React.FC<PaginationProps> = ({
  currentPage,
  totalPages,
  pageSize,
  pageSizeOptions,
  onPageChange,
  onPageSizeChange,
  totalItems
}) => {
  // Create an array of page numbers to display
  const getPageNumbers = () => {
    const pages: number[] = [];
    const maxPagesToShow = 5; // Show at most 5 page numbers
    
    if (totalPages <= maxPagesToShow) {
      // If we have 5 or fewer pages, show all of them
      for (let i = 1; i <= totalPages; i++) {
        pages.push(i);
      }
    } else {
      // Always include page 1
      pages.push(1);
      
      // Calculate start and end of the current window
      let startPage = Math.max(2, currentPage - 1);
      let endPage = Math.min(totalPages - 1, currentPage + 1);
      
      // Adjust the window if we're near the start or end
      if (currentPage <= 3) {
        endPage = 4;
      } else if (currentPage >= totalPages - 2) {
        startPage = totalPages - 3;
      }
      
      // Add ellipsis after page 1 if needed
      if (startPage > 2) {
        pages.push(-1); // Use -1 as a marker for ellipsis
      }
      
      // Add the window of pages
      for (let i = startPage; i <= endPage; i++) {
        pages.push(i);
      }
      
      // Add ellipsis before the last page if needed
      if (endPage < totalPages - 1) {
        pages.push(-2); // Use -2 as another marker for ellipsis
      }
      
      // Always include the last page
      if (totalPages > 1) {
        pages.push(totalPages);
      }
    }
    
    return pages;
  };
  
  // Calculate the range of items being displayed
  const startItem = totalItems === 0 ? 0 : (currentPage - 1) * pageSize + 1;
  const endItem = Math.min(currentPage * pageSize, totalItems);
  
  return (
    <div className='paginationContainer'>
      <div className='pageInfo'>
        {totalItems > 0 ? (
          <>Showing {startItem}-{endItem} of {totalItems} items</>
        ) : (
          <>No items to display</>
        )}
      </div>
      
      <div className='pagination'>
        <button
          onClick={() => onPageChange(1)}
          disabled={currentPage === 1 || totalPages === 0}
          className='pageButton'
          title="First page"
        >
          &laquo;
        </button>
        
        <button
          onClick={() => onPageChange(currentPage - 1)}
          disabled={currentPage === 1 || totalPages === 0}
          className='pageButton'
          title="Previous page"
        >
          &lsaquo;
        </button>
        
        {getPageNumbers().map((page, index) => (
          page < 0 ? (
            <span key={`ellipsis-${index}`} className='ellipsis'>...</span>
          ) : (
            <button
              key={page}
              onClick={() => onPageChange(page)}
              disabled={page === currentPage}
              className={`pageButton ${page === currentPage ? 'activePage' : ''}`}
            >
              {page}
            </button>
          )
        ))}
        
        <button
          onClick={() => onPageChange(currentPage + 1)}
          disabled={currentPage === totalPages || totalPages === 0}
          className='pageButton'
          title="Next page"
        >
          &rsaquo;
        </button>
        
        <button
          onClick={() => onPageChange(totalPages)}
          disabled={currentPage === totalPages || totalPages === 0}
          className='pageButton'
          title="Last page"
        >
          &raquo;
        </button>
      </div>
      
      <div className='pageSize'>
        <label htmlFor="page-size">Items per page:</label>
        <select 
          id="page-size"
          value={pageSize}
          onChange={(e) => onPageSizeChange(Number(e.target.value))}
          className='pageSizeSelect'
        >
          {pageSizeOptions.map(size => (
            <option key={size} value={size}>{size}</option>
          ))}
        </select>
      </div>
    </div>
  );
};

export default Pagination;
