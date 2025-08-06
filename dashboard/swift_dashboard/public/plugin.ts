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

import { 
  AppMountParameters, 
  CoreSetup, 
  CoreStart, 
  Plugin,
  PluginInitializerContext 
} from '../../../src/core/public';
import { 
  SwiftDashboardPluginSetup, 
  SwiftDashboardPluginStart,
  AppPluginStartDependencies
} from './types';
 
import { renderApp } from './applications/swift_dashboard_app/swiftDashboard'
export class SwiftDashboardPlugin implements Plugin<SwiftDashboardPluginSetup, SwiftDashboardPluginStart> {
  private readonly initializerContext: PluginInitializerContext;

  constructor(initializerContext: PluginInitializerContext) {
    this.initializerContext = initializerContext;
  }

  public setup(core: CoreSetup): SwiftDashboardPluginSetup {
    // Register your application with OpenSearch Dashboards
    core.application.register({
      id: 'swiftDashboard',
      title: 'SWIFT Dashboard',
      category: {
        id: 'swiftPlugin',
        label: 'SWIFT Analytics',
        order: 1000,
      },
      order: 1000,
      appRoute: '/app/swiftDashboard',
      async mount(params: AppMountParameters) {
        // Create a root element with your plugin's namespace
        const { element } = params;
        element.classList.add('swift-dashboard-plugin');
        
        // Safer dynamic import
        try {
            // const applicationsModule = await import('./applications/index.ts.bkp');
            // console.log('Applications module imported:', applicationsModule);
            
            if (!renderApp) {
              throw new Error('renderApp function not found in applications module');
            }
            
            const [coreStart, depsStart] = await core.getStartServices();
            
            return renderApp(params, coreStart, depsStart as AppPluginStartDependencies);
          } catch (error) {
            element.innerHTML = `<div class="euiText euiText--medium">
              <p>Failed to load SWIFT Dashboard application. Error: ${error instanceof Error ? error.message : String(error)}</p>
              <p>Please check browser console for details.</p>
            </div>`;
            return () => {};
          }
      },
    });

    return {};
  }

  public start(core: CoreStart): SwiftDashboardPluginStart {
    return {};
  }

  public stop() {}
}
