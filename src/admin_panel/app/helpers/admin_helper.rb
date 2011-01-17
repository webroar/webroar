#--
# WebROaR - Ruby Application Server - http://webroar.in/
# Copyright (C) 2009  Goonj LLC
#
# This file is part of WebROaR.
#
# WebROaR is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# WebROaR is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with WebROaR.  If not, see <http://www.gnu.org/licenses/>.
#++

# Methods added to this helper will be available to all view files for the admin controller.
module AdminHelper
  #This method is used to populate the rows of application data in the configuration page.
  #This method is called from configuration.html.erb.
  def application_list(start = 0)
    i = start 
    list_array = Array.new
    index = 1
    if (@info['Application Specification'])
      while(@info['Application Specification'][i] and i < start+5)
        application = ApplicationSpecification.get_hash(i)
        #link="http://#{request.host}:#{request.port}#{h(application[:resolver])}"        
        str = "<tr>
        <td>#{h(application[:name])}</td>
        <td>#{h(application[:resolver])}</td>
        <td>#{h(application[:type1])}</td>
        <td>#{h(application[:analytics])}</td>
        <td>#{h(application[:environment])}</td>
        <td>#{h(application[:min_worker])}</td>
        <td>#{h(application[:max_worker])}</td>
        <td><center>#{link_to 'Edit', :controller => 'application_specification', :action => 'edit_application_form', :id => application[:name]}</center></td>
        <td><center>#{link_to_remote 'Delete', {:url => {:controller => 'application_specification', :action=>'delete_application', :id => application[:name]}, :before => "show_busy_div()", :complete => "hide_busy_div(request)", :update => "dummy_div", :confirm=>DELETE_APPLICATION_ALERT_MESSAGE, :oncontextmenu => 'return false;' }}</center></td>
        <td><center>#{link_to_remote 'Restart', {:url => {:controller => 'application_specification', :action => 'restart_application', :id => application[:name]}, :before => "show_busy_div()", :complete => "hide_busy_div(request)", :update => "dummy_div", :confirm=>RESTART_APPLICATION_ALERT_MESSAGE, :oncontextmenu => 'return false;'}}</center></td></tr>"
        list_array[i] = str
        i += 1
      end
    end   
    return list_array.join("\n")
  end
  
  #This method is used to populate the rows of application data on the Home page.
  #This method is called from home.html.erb.
  def application_list_home
    i = 0
    list_array = Array.new
    index = 1
    if (@info['Application Specification'])
      while(@info['Application Specification'][i])
        application = ApplicationSpecification.get_hash(i)
        if @apps_resource_usage[application[:name]]
          cpu_usage = @apps_resource_usage[application[:name]][0].to_s
          memory_usage = format("%.2f",@apps_resource_usage[application[:name]][1]/1024).to_f
        else
          cpu_usage = 0.0.to_s
          memory_usage = 0.0.to_s
        end	
        exception_count = App.exceptions_count(application[:name])
        if exception_count > 0 
          link_text = "Yes (#{exception_count})"
          exception_td_data = "<span id='#{application[:name]}_exception' >#{link_to link_text, :controller => 'exceptions', :action => 'get_exceptions_list', :application_name => application[:name]}</span>"
        else
          exception_td_data = "<span id='#{application[:name]}_exception'>No</span>"
        end
        #link="http://#{request.host}:#{request.port}#{h(application[:resolver])}"
        list_array[i] = "<tr>
				<td width = 25%>#{h(application[:name])}</td>
				<td width = 15%><span id = '#{application[:name]}_cpu'>#{h cpu_usage}</span> %</td>
				<td width = 15%><span id = '#{application[:name]}_memory'>#{h memory_usage}</span> MB</td>
				<td width = 15%>#{h application[:min_worker]}</td>
				<td width = 15%>#{h application[:max_worker]}</td>"
        if  application[:type1].downcase == 'rails'
          list_array[i] = list_array[i]+ " <td width = 15%>#{exception_td_data}</td></tr>"
        else
          list_array[i] = list_array[i]+  "<td width = 15%>--</td></tr>"
        end
        i += 1		
      end
    end
    return list_array.join("\n")
  end
  
  #This method is used to old values in the server specification in configuration page.
  #This method is called from add_div partial.
  def get_old_value_for_div(div_id)
    port, min_worker, max_worker, log_level, ssl_support, ssl_port, certificate, key, access_log = ServerSpecification.get_fields
    if params[:div_id] == 'port_div'	
      old_value = port
    elsif params[:div_id] == 'min_pro_div'
      old_value = min_worker
    elsif params[:div_id] == 'max_pro_div'
      old_value = max_worker
    elsif params[:div_id] == 'ssl_port_div'
      old_value = ssl_port
    elsif params[:div_id] == 'certificate_div'
      old_value = certificate
    elsif params[:div_id] == 'key_div'
      old_value = key
    elsif params[:div_id] == 'log_div'
      old_value = log_level
    elsif params[:div_id] == 'access_log_div'
      old_value = access_log
    end
    return old_value
  end
  
  #To help the configuration page to display the ssl information.
  def ssl_block(info, ssl_port, certificate, key)
    if info['Server Specification']['SSL Specification']
      block = "<table width = 95% >
			      <tr>
      				<th width = 80%>SSL Support</td>
              <th>"
      if info['Server Specification']['SSL Specification']['ssl_support'] == 'enabled'
        block = block + "#{link_to('Disable', :controller => 'server_specification', :action => 'disable_ssl_support', :id => 0)}"
        block = block + "</th>
                  </tr>"
        block = block + "<tr>
            				  <td width = 40%>SSL Port&nbsp;&nbsp;&nbsp;
                      				#{link_to_function('Help', :onclick => 'addHelp("ssl_port",event);')}
                    			<br/> <div id = 'ssl_port' class = 'font_size_12'></div>
                      </td>
            				  <td width = 40%><div id = 'ssl_port_div'>#{ssl_port}</td>
	            			  <td width = 40%>#{link_to_remote 'Edit', :update => 'ssl_port_div', :url => {:action => 'add_text_box', :div_id => 'ssl_port_div'}}</td>
	          		  </tr>
	          		  <tr>
	            			  <td>SSL Certificate Path&nbsp;&nbsp;&nbsp;
                      				#{link_to_function('Help', :onclick => 'addHelp("ssl_certificate",event);')}
                    			<br/> <div id = 'ssl_certificate' class = 'font_size_12'></div>
                      </td>
	            			  <td><div id = 'certificate_div'>#{certificate}</div></td>
            				  <td>#{link_to_remote 'Edit', :update => 'certificate_div', :url => {:action => 'add_text_box', :div_id => 'certificate_div'}}</td>
          			  </tr>
          			  <tr>
				              <td >Machine key path&nbsp;&nbsp;&nbsp;
                      				#{link_to_function('Help', :onclick => 'addHelp("ssl_key",event);')}
                    			<br/> <div id = 'ssl_key' class = 'font_size_12'></div>
                      </td>
            				  <td><div id = 'key_div'>#{key}</td>
            				  <td>#{link_to_remote 'Edit', :update => 'key_div', :url => {:action => 'add_text_box', :div_id => 'key_div'}}</td>
          			  </tr>
            	  </table>"
      else
        block = block + "#{link_to_remote 'Enable', :update => 'ssl_div', :url => {:controller => 'server_specification', :action => 'ssl_support_form', :id => 1}}"
        block = block + "</th>
                  </tr>
              </table>"
      end
      block = block + "<div id = 'ssl_div'>#{if flash[:ssl_errors]
      render :partial => 'server_specification/ssl_support_form'
      end}</div><br/><br/>"
    end
    return block
  end
end
