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

# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  #This method is used to get the tabs image for the differnt tabs in the admin panel.
  def get_tab_class_name(controller_name,action_name)
    tab1 = ["home","home_ov"]
    tab2 = ["configuration","configuration_ov"]
    tab3 = ["analytics","analytics_ov"]
    tab4 = ["exceptions","exceptions_ov"]
    tab5 = ["settings","settings_ov"]
    tab6 = ["contact_us","contact_us_ov"]
    if controller_name == 'admin'
      case action_name
      when "home"
        tab1 = ["home_ov",""]
      when "change_password_form"
        tab5 = ["settings_ov",""]
      when "change_password"
        tab5 = ["settings_ov",""]
      when "contact_us","send_feedback","send_report_bug"
        tab6 = ["contact_us_ov",""]
      else
        tab2 = ["configuration_ov",""]
      end
    elsif controller_name == 'graph'
      tab3 = ["analytics_ov",""]
    elsif controller_name == 'exceptions'
      tab4 = ["exceptions_ov",""]
    end
    return tab1,tab2,tab3,tab4,tab5,tab6
  end
  
end
