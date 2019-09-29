
module TimeZoneHelper

    def time_test
        Time.now
    end

    def get_country_time_zones(country = 'US')
        ActiveSupport::TimeZone.country_zones(country)
        # ActiveSupport::TimeZone.us_zones
    end

    def formatted_date (time, options = {})
        if options[:org_id].present? && options[:time_zone].blank?
            options[:time_zone] = Organization.find(options[:org_id]).root_org_setting('time_zone') 
        end
        options[:strftime] = "%_m-%_e-%_Y %_l:%M%P" if options[:strftime].blank? 
        return time.in_time_zone(options[:time_zone]).strftime(options[:strftime])
        # return time.in_time_zone(options[:time_zone]).strftime("%m-%e-%Y %l:%M%P")
    end

    def timestamp_tag(time, options= {})
        content_tag( :div, 
            content_tag( :time, 
                "#{options[:prefix]} #{formatted_date(time,options)} #{options[:suffix]}",
                datetime: time 
            )
        )
    end

    def same_time? time1, time2, range = 0
        return (time1 - time2) < range
    end

end