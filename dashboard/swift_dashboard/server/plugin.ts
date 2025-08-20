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
  CoreSetup,
  CoreStart,
  Plugin,
  Logger,
  PluginInitializerContext,
} from '../../../src/core/server';
import {registerRoutes}  from './routes';
import { PluginContext, SwiftDashboardServerPluginSetup, SwiftDashboardServerPluginStart } from './types';

export class SwiftDashboardServerPlugin implements Plugin<SwiftDashboardServerPluginSetup, SwiftDashboardServerPluginStart> {
  private readonly logger: Logger;

  constructor(initializerContext: PluginInitializerContext) {
    this.logger = initializerContext.logger.get();
  }

  public setup(core: CoreSetup, plugins: object): SwiftDashboardServerPluginSetup {
    this.logger.debug('Swift Dashboard: Setup');
    
    // Register server routes
    const router = core.http.createRouter();
    
    // Create the plugin context with logger and configuration
    const pluginContext: PluginContext = {
      logger: this.logger,
      config: {
        enabled: true,
        index: 'translated_log', // Default index name
        cacheTTL: 5 * 60 * 1000 // 5 minutes in milliseconds
      }
    };
    
    // Pass the plugin context to the routes
    registerRoutes(router, pluginContext);
    
    return {};
  }

  public start(core: CoreStart): SwiftDashboardServerPluginStart {
    this.logger.debug('Swift Dashboard: Started');
    return {};
  }

  public stop(): void {
    this.logger.debug('Swift Dashboard: Stopped');
  }
}
