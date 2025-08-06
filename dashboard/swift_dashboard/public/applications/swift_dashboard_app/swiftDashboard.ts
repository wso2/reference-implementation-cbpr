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
import ReactDOM from 'react-dom';
import { AppMountParameters, CoreStart } from '../../../../../src/core/public';
import { AppPluginStartDependencies } from '../../types';
import { BrowserRouter } from 'react-router-dom';
import App from './components/App';

export const renderApp = (
  { element }: AppMountParameters,
  coreStart: CoreStart,
  plugins: AppPluginStartDependencies
) => {
  
  const AppElement = React.createElement(
    App,
    { coreStart, plugins }
  );
  
  //Create the Router element manually
  const RouterElement = React.createElement(
    BrowserRouter,
    { basename: '/app/swiftDashboard' },
    AppElement
  );
  
  // Render the element tree
  ReactDOM.render(RouterElement, element);

  return () => ReactDOM.unmountComponentAtNode(element);
};
