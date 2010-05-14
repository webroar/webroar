/*
WebROaR - Ruby Application Server - http://webroar.in/

Copyright (C) 2009  Goonj LLC

This file is part of WebROaR.

WebROaR is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

WebROaR is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with WebROaR.  If not, see <http://www.gnu.org/licenses/>.
*/


function addHelp(id)
{
	if(id=='resolver')
	{
	    str="Please enter '/' if you would like to run this application on the root domain. e.g. http://yourserver:port/. Else please enter the relevant base URI with which you would like to access this specific application, e.g. '/app1' if you want the application to be accessible via http://yourserver:port/app1.<br/><br/>If you would like to set a virtual host for your application e.g. www.company1.com, please specify it here. You can also host this application on a particular subdomain e.g. app1.company1.com.<br/><br/>Wildcard '*' can also be used in defining the virtual host name, but it should only be used either at the start or the end. Prefix the virtual host name with tilde(~), if a wildcard is used in defining it. e.g. (i) ~*.server.com  (ii) ~www.server.*  (iii) ~*.server.* "	
	}
	if(id=='path')
	{
		str="Please enter the complete path for your web application root directory: e.g. /home/someuser/webapps/app1."
	}
	if(id=='runasuser')
	{
		str="Please enter the name of the user with whose privileges you would like to run this application. (root can be dangerous!). This user should have all the necessary permissions to get your web application working properly. (e.g. write access on required files and directories etc)."
  $("application_specification_type1").hide();
  $("application_specification_analytics").hide();
	}	
	if(id=='analytics')
	{
		str="Set this to enabled if you would like to get detailed numbers about the run time performance of this application. This number gathering adds a very small overhead on your application. (Typically it adds < 3ms of additional processing time to the request)."
  $("application_specification_environment").hide();
	}
	if(id=='minworker')
	{
		str="Default minimum number of worker processes that should run for any deployed application. Multiple worker instances help in processing a higher number of concurrent user requests simultaneously.<br/>(This value can be overridden for a specific application while deploying it.)"
	}

	if(id=='maxworker')
	{
		str="Default maximum number of worker processes that should run for any deployed application. Multiple worker instances help in processing a higher number of concurrent user requests simultaneously.<br/>(This value can be overridden for a specific application while deploying it.)"
	}
	if(id=='most')
	{
		str="<b>Most Time Consuming URLs : </b>URLs whose response generation took the maximum cumulative time for the specified duration. These could be the prime candidate for optimizations." 
	}	
	if(id=='hits')
	{
		str="<b>URL Hits : </b>The hit count for the URLs of the application for the specified duration." 
	}	
	if(id=='slowest')
	{
		str="<b>Slowest URLs : </b>URLs whose 'average' time for the response generation was maximum. These are the slowest part of the application, out of all those accessed in the specified duration." 
	}	
	if(id=='db')
	{
		str="<b>Database Consuming URLs : </b>URLs whose code spends the maximum time in the database ORM layer." 
	}	
	if(id=='port')
	{
		str="<b>Port   : </b>Application server port number." 
	}	
	if(id=='log_level')
	{
		str="Set the default logging level for the server and it's deployed applications. (INFO/WARN/SEVERE/FATAL). The logs are available in /var/log/webroar." 
	}	
	if(id=='ssl_port')
	{
		str="Secure Sockets Layer(SSL) authentication port number." 
	}	
	if(id=='ssl_certificate')
	{
		str="Complete path to the SSL certificate file. e.g. /home/smartuser/ssl-cert/certificate.crt" 
	}	
	if(id=='ssl_key')
	{
		str="Complete path to the SSL key file. e.g. /home/smartuser/ssl-cert/mymachine.key" 
	}	
  if(id=='remaining_time')
  {
    str="<b>Remaining Time </b>covers time spent in executing filters, called actions (statements other than database calls), user defined methods in model, session management by framework etc. "
  }
  if(id=='access_log')
  {
    str="Set access log to enabled to capture all HTTP requests to the server. The log is available in /var/log/webroar."
  }
  if(id=='type')
  {
    str="In case you are deploying a rack compliant application (merb, sinatra, mack etc), please do create a config.ru file in it's root directory. Please refer the README or the user guide for more details."
    $("application_specification_environment").hide();
    $("application_specification_analytics").hide();
  }
  if(id=='app_minworker')
  {
    str="Please enter the minimum number of worker processes that should run for this deployed application. Multiple worker instances help in processing a higher number of concurrent user requests simultaneously. The server would always ensure at least these many worker processes run for this application."
  }
  if(id=='app_maxworker')
  {
    str="Please enter the maximum number of worker processes that should run for this deployed application. Multiple worker instances help in processing a higher number of concurrent user requests simultaneously. The server would ensure that maximum only these many worker processes run for this application."
  }



  /*Help for mail settings*/
  if(id=='mail')
  {
    str="Configure email settings to receive notifications from the server about the status of the deployed applications. WebROaR can use either SMTP or Sendmail to send these emails."
  }
  if(id=='smtp_server')
  {
    str="Host name or IP address of the SMTP Server."
  }
  if(id=='smtp_domain')
  {
    str="Hosting domain of your sender email account. e.g. gmail.com."
  }
  if(id=='smtp_authentication')
  {
    str="Authentication type of the SMTP account (login/plain/cram-md5/ntlm-spa/digest-md5)."
  }
  if(id=='smtp_username')
  {
    str="Username of the email account e.g. smartuser."
  }
  if(id=='smtp_password')
  {
    str="Password of the email account."
  }
  if(id=='smtp_recipients_id' || id=='sendmail_recipients_id')
  {
    str="Comma separated list of email addresses to whom WebROaR should send notification emails about the deployed applications status."
  }
  if(id=='sendmail_location')
  {
    str="Location of the sendmail agent e.g. /usr/sbin/sendmail"
  }  
  if (id == 'headers') 
  {
    str = "It allows adding or changing the Expires and Cache-Control in the response headers for static assets (e.g. *.js, *.gif etc)."
  }
  if (id == 'expires') 
  {
    str = "Expires header for all static assets (optional) (default is 'off'). Possible value for expires is off or no. of seconds."
  }
  if (id == 'expires_by_type') 
  {
    str = "Specific expires header for specific file types."
  }
  if (id == 'expires_by_type_ext') 
  {
    str = 'File extensions separated by comma (e.g png, jpg, gif).'
  }
  if (id == 'expires_by_type_expires_value') 
  {
    str = "Expires value in no. of seconds."
  }
  if(id=='runasuser')
  {
	  str=str+"<div style='width:99%;text-align:right'><a href=# onClick=\" $('application_specification_type1').show(); $('application_specification_analytics').show(); $('"+id+"').hide(); return false;\" class='calendar_link'>Close</a></div>"
  }
  else if (id=='analytics')
  {
	  str=str+"<div style='width:99%;text-align:right'><a href=# onClick=\" $('application_specification_environment').show(); $('"+id+"').hide(); return false;\" class='calendar_link'>Close</a></div>"
  }
  else if (id=='type') 
  {   
	  str=str+"<div style='width:99%;text-align:right'><a href=# onClick=\" $('application_specification_environment').show(); $('application_specification_analytics').show(); $('"+id+"').hide(); return false;\" class='calendar_link'>Close</a></div>"
  }
  else
  {
	  str=str+"<div style='width:99%;text-align:right'><a href=# onClick=\"$('"+id+"').hide(); return false;\" class='calendar_link'>Close</a></div>"
  }  
	$(id).show();
	$(id).update(str).addClassName('popup_container').show();
}


function disableAnalytics(type)
{    
    document.getElementById('application_specification_analytics').options.length=0;
    if(type=="Rails")
    {
        document.getElementById('application_specification_analytics').options[0]=new Option("Disabled");
        document.getElementById('application_specification_analytics').options[1]=new Option("Enabled");
    }
    else
    {
        document.getElementById('application_specification_analytics').options[0]=new Option("Disabled");
    }
    
}


function getFlashVersion(){
        try {
          try {
              var axo = new ActiveXObject('ShockwaveFlash.ShockwaveFlash.6');
              try { axo.AllowScriptAccess = 'always'; }
              catch(e) { return '6,0,0'; }
            } catch(e) {}
            return new ActiveXObject('ShockwaveFlash.ShockwaveFlash').GetVariable('$version').replace(/\D+/g, ',').match(/^,?(.+),?$/)[1];
          } catch(e) {
            try {
              if(navigator.mimeTypes["application/x-shockwave-flash"].enabledPlugin){
                return (navigator.plugins["Shockwave Flash 2.0"] || navigator.plugins["Shockwave Flash"]).description.replace(/\D+/g, ",").match(/^,?(.+),?$/)[1];
              }
            } catch(e) {}
          }
       return '0,0,0';
}

function checkFlashPlayer()
{
   var version = getFlashVersion().split(',').shift();
     if(version==0){
        alert("Please install Flash Player plugin to view the graphs on this page.");
     }
 }

function show_busy_div(){
    //$('body_container').setStyle({display: 'none'})
    $('loading_progress1').setStyle({display: 'block'})
    $('loading_progress').setStyle({display: 'block'})
}
function hide_busy_div(request){    
    //$('body_container').setStyle({display: 'block'})
    $('loading_progress').setStyle({display: 'none'})   
    $('loading_progress1').setStyle({display: 'none'})
}

  function setToolTip(start_time,end_time,count){
	a_name1="#"+count+"1";
	a_name2="#"+count+"2";	
	if (parseInt(start_time) <= 0 && parseInt(start_time)==parseInt(end_time))
	{
		$j(a_name1).text(start_time+":00");	
		$j(a_name2).text(end_time+":00");
	}
	else 
	{
		if(parseInt(start_time)==parseInt(end_time))
		{
			start_hour=start_time-1;
			end_hour=end_time-1;
			$j(a_name1).text(start_hour+":59");	
			$j(a_name2).text(end_hour+":59");
		}
		else
		{
			end_hour=end_time-1;
			$j(a_name1).text(start_time+":00");	
			$j(a_name2).text(end_hour+":59");
		}	
	}
	}	

  function setValue(start_time,end_time,app_id,graph_id,count){
	setToolTip(start_time,end_time,count);
        var graph_date=$('date').value;
	      if(graph_id=="server_cpu_usage_graph")	
	      {
			      new Ajax.Updater({success:'server_cpu_usage_graph',failure:'err_msg_div'}, '/admin-panel/graph/get_server_cpu_usage_graph?date='+graph_date +'&start_time='+ start_time+'&end_time='+ end_time, {asynchronous:true, evalScripts:true}); 
	      }		
	      if(graph_id=="server_memory_usage_graph")	
	      {
			      new Ajax.Updater({success:'server_memory_usage_graph',failure:'err_msg_div'}, '/admin-panel/graph/get_server_memory_usage_graph?date='+graph_date +'&start_time='+ start_time+'&end_time='+ end_time, {asynchronous:true, evalScripts:true}); 
	      }		
        if(graph_id=="percentage_db_usage_graph")
	      {
			      new Ajax.Updater({success:'percentage_db_usage_graph',failure:'err_msg_div'}, '/admin-panel/graph/percentage_time_spent_in_db_layer?app_id='+app_id+'&date='+graph_date +'&start_time='+ start_time+'&end_time='+ end_time, {asynchronous:true, evalScripts:true}); 
	      }		
        if(graph_id=="avg_res_time_graph")
	      {
			      new Ajax.Updater({success:'avg_res_time_graph',failure:'err_msg_div'}, '/admin-panel/graph/average_response_graph?app_id='+app_id+'&date='+graph_date +'&start_time='+ start_time+'&end_time='+ end_time, {asynchronous:true, evalScripts:true}); 
	      }		
        if(graph_id=="app_throughput_graph")
	      {
			      new Ajax.Updater({success:'app_throughput_graph',failure:'err_msg_div'}, '/admin-panel/graph/peak_requests_graph?app_id='+app_id+'&date='+graph_date +'&start_time='+ start_time+'&end_time='+ end_time, {asynchronous:true, evalScripts:true}); 
	      }		
        if(graph_id=="app_cpu_usage_graph")
	      {
			      new Ajax.Updater({success:'app_cpu_usage_graph',failure:'err_msg_div'}, '/admin-panel/graph/percentage_cpu_usage_graph?app_id='+app_id+'&date='+graph_date +'&start_time='+ start_time+'&end_time='+ end_time, {asynchronous:true, evalScripts:true}); 
	      }		
        if(graph_id=="app_memory_usage_graph")
	      {
			      new Ajax.Updater({success:'app_memory_usage_graph',failure:'err_msg_div'}, '/admin-panel/graph/memory_usage_graph?app_id='+app_id+'&date='+graph_date +'&start_time='+ start_time+'&end_time='+ end_time, {asynchronous:true, evalScripts:true}); 
	      }		

   }


window.onload = function() {
  // the element in which we will observe all clicks and capture
  // ones originating from pagination links
  var container = $(document.body)

  if (container) {
    var img = new Image
    img.src = '/admin-panel/images/spinner.gif'

    function createSpinner() {
      return new Element('img', { src: img.src, 'class': 'spinner' })
    }

		container.observe('click', function(e) {
      var el = e.element()
      if (el.match('.pagination a')) {
        //el.up('.pagination').insert(createSpinner())
        new Ajax.Request(el.href, { method: 'get' })
        e.stop()
      }
    })
  }
}


function checkall(element) {
  allCheckboxes = $('form_exception_list').getInputs('checkbox')
    
  if (element.checked == true) {
      for (i = 0; i < allCheckboxes.length; i++) {          
          allCheckboxes[i].checked = true;
      }
  }
  else {
      for (i = 0; i < allCheckboxes.length; i++) {
          allCheckboxes[i].checked = false;
      }
  }
}

function checkMarked(arg) {
	allCheckboxes = $('form_exception_list').getInputs('checkbox')
	for (i = 0; i < allCheckboxes.length; i++)
	  if ( allCheckboxes[i].checked == true)
		  if(arg == 'delete') 
				return confirm("Are you sure to delete selected exceptions?")				  
			else 
			 return true	
						
		  
	alert('No exception selected')
	return false
}
