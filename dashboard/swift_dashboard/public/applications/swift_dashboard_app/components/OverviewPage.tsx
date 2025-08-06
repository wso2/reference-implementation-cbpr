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

import React, { useState } from 'react';
import ChartComponent from './ChartComponent';
import SummaryComponent from './ErrorComponent';
import MessageTypeDistribution from './MessageTypeDistribution';
import RecentActivity from './RecentActivity';
import useWindowSize from './hooks/useWindowSize';
import ToggleBar from './ToggleBar';
import './OverviewPage.scss';
import './commonStyles.scss';

// Define proper types for your filter options
type PeriodType = 'Daily' | 'Weekly' | 'Monthly';
type DirectionType = 'All' | 'Inward' | 'Outward';

const OverviewPage: React.FC = () => {
  const [timeFilter, setTimeFilter] = useState<PeriodType>('Monthly');
  const [directionFilter, setDirectionFilter] = useState<DirectionType>('All');

  const messageCompletion = ChartComponent({ type: "pie", direction: directionFilter, period: timeFilter });
  const messageTrend = ChartComponent({ type: "bar", direction: directionFilter, period: timeFilter });

  // Handle period toggle with proper typing
  const handlePeriodToggle = (option: PeriodType) => {
    setTimeFilter(option);
  };

  // Handle direction toggle with proper typing
  const handleDirectionToggle = (option: DirectionType) => {
    setDirectionFilter(option);
  };

  return (
    <div className="overview-page">
    <div className="toggle-overview">
    <ToggleBar
            options={['Monthly', 'Weekly', 'Daily']}
            activeOption={timeFilter}
            onToggle={handlePeriodToggle as (option: string) => void}
            debounceTime={400}
          />
          <ToggleBar
            options={['All', 'Inward', 'Outward']}
            activeOption={directionFilter}
            onToggle={handleDirectionToggle as (option: string) => void}
            debounceTime={400}
          />
        </div>
      <div className="dashboard-row">
        <div className="dashboard-column completion">
          {messageCompletion}
        </div>
        <div className="dashboard-column trend">
          {messageTrend}
        </div>
      </div>
      
      <div className="dashboard-row">
        <div className="dashboard-column distribution">
          <MessageTypeDistribution title="MT Message Type Distribution" period={timeFilter} direction={directionFilter} />
        </div>
        <div className="dashboard-column activity">
          <RecentActivity title="Recent Activity" direction={directionFilter} period={timeFilter}/>
        </div>
        <div className="dashboard-column errors">
            <SummaryComponent title="Translation Failures" timeFilter={timeFilter} direction={directionFilter}/>
        </div>
      </div>
    </div>
  );
};

export default OverviewPage;
