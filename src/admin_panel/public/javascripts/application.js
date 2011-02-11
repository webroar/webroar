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


function addHelp(id,event)
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
	}	
	if(id=='analytics')
	{
		str="Set this to enabled if you would like to get detailed numbers about the run time performance of this application. This number gathering adds a very small overhead on your application. (Typically it adds < 3ms of additional processing time to the request)."  
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
  if (id == 'exception_class')
  {
    str = "Exception falls into given Exception Class would not be notified(also it won't be listed in Open exception list). Please note that exception which already occurred would not be affected.";
  }
  str=str+"<div class='text_align_right'><a href=# onClick=\"$('"+id+"').hide(); return false;\" class='calendar_link'>Close</a></div>"
  $j(".font_size_12").hide();
  $(id).update(str).addClassName('popup_container').show();
  var x = getX(event) - $("container").offsetLeft;
  var y = getY(event) - $("container").offsetTop;
  if(x > 470)
	  x = 470;
  $(id).setStyle({left :x,top :y});
}
function getX(event)
{
	return event.clientX + document.body.scrollLeft + document.documentElement.scrollLeft;
}
function getY(event)
{
	return event.clientY + document.body.scrollTop + document.documentElement.scrollTop;
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


function uncheckMain(element)
{	
	var main_checkbox = document.getElementById("check_all");
	var check = false;
	if (element.checked == false) {
		
		main_checkbox.checked = check;
	}
	else 
	{
		var input_elements = document.form_exception_list.exception_ids_;
		for (i = 0; i < input_elements.length; i++) 
		{						
			if (input_elements[i].checked == true) 
				check = true;			
			else 
			{
				check = false;
				break;
			}
		}
		if(!input_elements.length)
			if(input_elements.checked==true)
				check=true;	
		main_checkbox.checked = check;
	}
	
}

function checkAll(self,element) {
      
  	if (self.checked == true) {
		element.checked=true;
        for (i = 0; i < element.length; i++)
		element[i].checked = true ;
		
    }
    else {
		element.checked=false;
       for (i = 0; i < element.length; i++)
		element[i].checked = false ;
    }	
}

function checkMarked(arg) {
	var input_elements = document.form_exception_list.exception_ids_;
	if (!input_elements) {
		alert('No exception selected...!');
		return false;
	}
	for (i = 0; i < input_elements.length; i++)
	{
		if (input_elements[i].checked == true) {
			return (confirm("Are you sure to "+arg+" selected exception(s)?"));
		}
	}
	if(input_elements.checked==true)
	{
			return (confirm("Are you sure to "+arg+" selected exception(s)?"));
	}             
    alert('No exception selected...!');	
    return false;
}
function validate_user(frm)
{
	name = frm.user_name.value;	
	password = frm.user_password.value;
	rv = true;			
	if(name.length == 0 && password.length == 0)
	{								
		document.getElementById("error_div").innerHTML = "Username/Password can't be blank.";
		return false;	 		 
	}
	if(name.length == 0)
	{			
		rv = false ;	
		document.getElementById("error_div").innerHTML = "Username can't be blank.";		
	}
	if(password.length == 0)
	{		
		rv = false;	
		document.getElementById("error_div").innerHTML = "Password can't be blank."; 
	}
	return rv;
}
var temp = "";

function validate_expire_by_type(frm)
{
	$j("#error_div_expire_by_type").css("padding","4");
	temp = "";
	var file_ext = frm.data_ext;
	var file_expire_time = frm.data_expires;
	
	validates_presence(file_ext, "File Extension");
	if(validates_presence(file_expire_time,"Expires Time"))
		validates_number(file_expire_time,"Expires Time");

	var error_div =	document.getElementById("error_div_expire_by_type");
	if(error_div) 
		error_div.innerHTML = temp; 
	
	if(temp.length > 4)
		return false;
	return true;

}
function validate_application(frm)
{
	$j("#error_div").css("padding","4");
	temp = "";	
	var app_name = frm.application_specification_name;
	var app_resolver = frm.application_specification_resolver;
	var app_path = frm.application_specification_path;
	var app_user = frm.application_specification_run_as_user;
	var app_env = frm.application_specification_environment;
	var app_min_worker = frm.application_specification_min_worker;
	var app_max_worker = frm.application_specification_max_worker;
	
	val = true;count = 0;
	
	val = validates_presence(app_name, "&nbsp;&nbsp;&nbsp;&nbsp; &#8226 Application Name");
	if(val == false)	count++;
	
	val = validates_presence(app_resolver, "&nbsp;&nbsp;&nbsp;&nbsp; &#8226 Application Resolver");
	if(val == false)	count++;
	
	val = validates_presence(app_path, "&nbsp;&nbsp;&nbsp;&nbsp; &#8226 Application Path");
	if(val == false)	count++;
	
	val = validates_presence(app_user, "&nbsp;&nbsp;&nbsp;&nbsp; &#8226 Application RunAsUser");
	if(val == false)	count++;
	
	val = validates_presence(app_env, "&nbsp;&nbsp;&nbsp;&nbsp; &#8226 Application Environment");
	if(val == false)	count++;
	
	if(validates_presence(app_min_worker,"&nbsp;&nbsp;&nbsp;&nbsp; &#8226 Minimum Number of Workers"))
	{	
		if(validates_number(app_min_worker,"&nbsp;&nbsp;&nbsp;&nbsp; &#8226 Minimum Number of Workers"))
		{
			if(!validates_value(app_min_worker,1,20,"&nbsp;&nbsp;&nbsp;&nbsp; &#8226 Minimum Number of workers"))
				count++;
		}
		else
			count++;
	}
	else
		count++;

	
	if(validates_presence(app_max_worker,"&nbsp;&nbsp;&nbsp;&nbsp; &#8226 Maximum Number of Workers"))
	{
		if(validates_number(app_max_worker,"&nbsp;&nbsp;&nbsp;&nbsp; &#8226 Maximum Number of Workers"))
		{
			if(!validates_value(app_max_worker,1,20,"&nbsp;&nbsp;&nbsp;&nbsp; &#8226 Maximum Number of workers"))
				count++;
		}
		else
			count++;
	}
	else
		count++;
	
				
	if(count > 1)
	{
		error_count_message = "<h2> "+count+" errors prohibited this application specification from being saved</h2> There were problems with following fields";
		document.getElementById("error_div").innerHTML = error_count_message+"<br><br>"+temp;
		val = false ;
	}
	if(count == 1)
	{
		error_count_message = "<h2> "+count+" error prohibited this application specification from being saved</h2> There were problems with following fields";
		document.getElementById("error_div").innerHTML = error_count_message+"<br><br>"+temp;
		val = false ;	
	}		
	return val;	
}

function validate_password(frm)
{
	$j("#error_div").css("padding","4");
	temp = "";
	var old_pass = frm.password_old;
	var new_pass = frm.password_new;
	var conf_pass= frm.password_confirm;	
	validates_presence(old_pass,"Old password");	
	if(validates_presence(new_pass,"New password"))
		validates_length(new_pass,6,20,"New password is too short (minimum is 6 characters)");
	if(validates_presence(conf_pass,"Confirm password"))
		validates_length(conf_pass,6,20,"Confirm password is too short (minimum is 6 characters)");
	
	validates_confirmation(new_pass, conf_pass);
	
	if(temp.length > 0)
	{
		document.getElementById("error_div").innerHTML = temp;
		return false;
	}
	return true;
}


//function to check presence of a field
function validates_presence(fld,message)
{		
	var fld_value = $j.trim(fld.value);	
	if(fld_value.length == 0)
	{								
		temp = temp +message+" can't be blank <br>";
		return false;
	}	
	return true;
}

//function to check length of a field
function validates_length(fld,min_length,max_length,message)
{
	fld_value = $j.trim(fld.value);	
	if((fld_value.length < min_length || fld_value.length > max_length ) && fld_value.length!=0)
	{						
		temp = temp + message+"<br>";
		return false;
	}		
	return true;	
}

//function to check confirmation of password
function validates_confirmation(fld1,fld2)
{	
	fld1_value = $j.trim(fld1.value);
	fld2_value = $j.trim(fld2.value);
	if(fld1_value != fld2_value && fld1_value.length!=0 && fld2_value.length!=0 && fld1_value.length >= 6 && fld2_value.length >= 6) 
	{							
		temp = temp + "doesn't match confirmation <br>";
		return false;
	}	
	return true;	
}


//function to check numerasity of a field
function validates_number(fld,message)
{			
	var fld_value = $j.trim(fld.value);	
	val = true;	
	number = "0123456789";
	fld_value = fld_value.split('');	
	i = 0;	
	while (i < fld_value.length) 
	{	
		if (number.indexOf(fld_value[i]) == -1) 
		{
			temp = temp + message+" is not a valid number<br>";			
			val = false;
			break;
		}
		i++;
	}	
	return val;
}

function validate_headers_expire(frm)
{	
	temp="";
	var data_value = frm.data_value;
	if(validates_presence(data_value,"Expires"))	
		validates_expires(data_value,"Expires");
	
	var div =	document.getElementById("expires_div");
	if(div)
		var str = frm.action;	
	
	old_data_value = ((((str.split('?')[1]).split('&'))[1]).split('='))[1];
	if(temp.length > 0)
	{				
		div.innerHTML =  old_data_value+"<span style='color:red;display:inline;'> "+temp+"</span>" ;
		return false;
	}
	return true;
}
function validates_expires(fld,message)
{		
	var fld_value  = $j.trim(fld.value);
	if((fld_value.toLowerCase()=="off" || fld_value.search(/^\d+$/)!=-1) || fld_value=="")
		return true;
	temp = temp + " Possible value for expires is no. of seconds or off<br>"; 
	return false
}
function validates_email(fld,message)
{
	var fld = $j.trim(fld);
	if(fld.length!=0)
	{
		if (fld.search(/^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i) == -1)
		{
			temp = temp + message+" is Invalid<br>";
			return false;
		}
	}
	return true;
}
function validate_smtp(frm)
{
	$j("#error_div_smtp_form").css("padding","4");
	temp = "";	
	var smtp_server = frm.smtp_address
	var smtp_domain = frm.smtp_domain
	var smtp_username = frm.smtp_user_name
	var sender_email_addr = frm.smtp_from
	var smtp_port = frm.smtp_port
	var smtp_authentication = frm.smtp_authentication
	var smtp_password = frm.smtp_password
	var reciever_email_addrs = frm.smtp_recipients		
	validates_presence(smtp_server, "SMTP Server");		
	validates_presence(smtp_domain, "SMTP Domain");
	validates_presence(smtp_username, "SMTP Username");
	
	if(validates_presence(sender_email_addr, "Senders Email Address"))
		validates_email(sender_email_addr.value, "Senders Email Address");
	
	if(validates_presence(smtp_port, "SMTP Port"))
		if(validates_number(smtp_port,"SMTP Port"))
			validates_value(smtp_port,1,65535,"SMTP Port");
	
	validates_presence(smtp_authentication,"SMTP Authentication");
	validates_presence(smtp_password,"SMTP Password");
	if(validates_presence(reciever_email_addrs,"Recipients Email Addresses"))
	{
		email_ids = reciever_email_addrs.value.split(',');
		i = 0 ;	
		while(i < email_ids.length)
		{
			validates_email(email_ids[i], "Recipients Email Addresse "+(i+1));
			i++;
		}
	}
	var error_div =	document.getElementById("error_div_smtp_form");
	
	if(error_div) 
		error_div.innerHTML = temp;
	
	if(temp.length > 0)
		return false;
	return true;
	
	
}
function validate_sendmail(frm)
{
	$j("#error_div_sendmail_form").css("padding","4");
	temp = "";	
	var sendmail_location = frm.sendmail_location;
	var sendmail_from = frm.sendmail_from;
	var sendmail_recipients = frm.sendmail_recipients;
			
	validates_presence(sendmail_location, "Sendmail Location");		
	
	if(validates_presence(sendmail_from, "Sender's Email Address"))
		validates_email(sendmail_from.value, "Sender's Email Address");
	
	if(validates_presence(sendmail_recipients, "Recipient Email Addresses"))
	{
		email_ids = sendmail_recipients.value.split(',');
		i = 0;
		while(i < email_ids.length)
		{
			validates_email(email_ids[i], "Recipients Email Addresse "+(i+1));
			i++;
		}
	}
	var error_div =	document.getElementById("error_div_sendmail_form");	
	if(error_div) 
		error_div.innerHTML = temp;
	
	if(temp.length > 0)
		return false;
	return true;
	
	
}
function validates_value(fld,min_range,max_range,message)
{
	fld_value = $j.trim(fld.value);
	if((fld_value < min_range || fld_value > max_range ) && fld_value.length!=0)
	{		
		temp = temp + message+" should be a number between "+min_range+" and "+max_range +"<br>";
		return false;
	}	
	return true;	
}

function validate_server_specification(frm)
{			
	temp = "";
	var str = frm.action;

	var div_id= ((((str.split('?')[1]).split('&'))[0]).split('='))[1];
	var old_data_value = ((((str.split('?')[1]).split('&'))[1]).split('='))[1];	
	var data_value = frm.data_value;			
	if(!(div_id=="log_div"))
	{
		if(div_id == "min_pro_div")
		{
			if(validates_presence(data_value,"Minimum Workers"))	
				if(validates_number(data_value,"Minimum Workers"))
					validates_value(data_value,1,20,"Minimum Workers");
		}
		else if(div_id== "max_pro_div")
		{
			if(validates_presence(data_value,"Maximum Workers"))	
				if(validates_number(data_value,"Maximum Workers"))
					validates_value(data_value,1,20,"Maximum Workers");
		}
		else if(div_id = "port_div")
		{			
			if(validates_presence(data_value,"Port Number"))		
				if(validates_number(data_value,"Port Number"))
					validates_value(data_value,1,65535,"Port Number");
		}
						
	}
	
	var div =	document.getElementById(div_id);		
	if(temp.length > 0)
	{				
		div.innerHTML =  old_data_value +" <span style='color:red;display:inline'>"+temp+"</span>" ;
		return false;
	}
	return true;
}

function validate_ssl(frm)
{			
	temp = "";
	var ssl_port = frm.ssl_port;
	var ssl_certificate_path = frm.ssl_certificate_path;
	var ssl_key_path = frm.ssl_key_path;
	if(validates_presence(ssl_port, "SMTP Port"))
		if(validates_number(ssl_port,"SMTP Port"))
			validates_value(ssl_port,1,65535,"SMTP Port");
	validates_presence(ssl_certificate_path, "SSL Certificate Path");
	validates_presence(ssl_key_path, "SSL Key Path");
	var error_div =	document.getElementById("error_div_ssl_form");	
	if(error_div)
		error_div.innerHTML = temp;
	if(temp.length > 0)
		return false;
	return true;
}