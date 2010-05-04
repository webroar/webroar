/* WebROaR - Ruby Application Server - http://webroar.in/
 * Copyright (C) 2009  Goonj LLC
 *
 * This file is part of WebROaR.
 *
 * WebROaR is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * WebROaR is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with WebROaR.  If not, see <http://www.gnu.org/licenses/>.
 */
#ifndef WR_CONFIGURATOR_H_
#define WR_CONFIGURATOR_H_

#include<wr_helper.h>

/** Remove application_configuration from configuration */
int wr_app_conf_remove(const char *app_name);
/** Read application configuration of specified application name */
config_application_list_t* wr_conf_app_read(const char *app_name, char* err_msg);
/** Read and update specified application */
config_application_list_t* wr_conf_app_update(const char *app_name, char* err_msg);
/** Replace the application configuration */
int wr_conf_app_replace(config_application_list_t *app_conf);
/** Destroy application configuration */
void wr_conf_app_free(config_application_list_t* app);


/** Read 'config.yml' file and fill configuration data structure */
int wr_conf_read();
/** Destroy configuration data structure */
void wr_conf_free();
/** Display configuration data structure */
void wr_conf_display();
/** Add Admin Panel to configuration data structure */
int wr_conf_admin_panel_add();
/** Add the configuration for static content server */
int wr_conf_static_server_add();
#endif /*WR_CONFIGURATOR_H_*/
