require 'aws-sdk'

module Linecook
   module Route53
     extend self

     def upsert_record(name, ami, region)
       ami_config = Linecook.config[:packager][:ami]

       zone = [ami_config[:zone], ami_config[:regions][region.to_sym], ami_config[:domain]].compact.join('.')
       record = "#{name}.#{zone}"

       resp = client.list_hosted_zones_by_name({
         dns_name: zone,
         max_items: 1,
       })

       if resp.hosted_zones.size < 1
         puts "Failed to find dns zone: #{resp.dns_name}"
         return false
       end


       zone_id = resp.hosted_zones[0].id
       client.change_resource_record_sets({
         hosted_zone_id: zone_id,
         change_batch: {
           comment: "create #{ami}",
           changes: [
             {
               action: "UPSERT",
               resource_record_set: {
                 name: record,
                 type: 'TXT',
                 ttl: 1,
                 resource_records: [
                   {
                     value: "\"#{ami}\"",
                   },
                 ],
               },
             },
           ],
         },
       })
       puts "Saved #{ami} to #{record}"
     rescue Aws::Route53::Errors::ServiceError => e
       puts "AWS Error: #{e.code} #{e.context.http_response.body_contents}"
       return false
     end

  private

    def client
      @client ||= begin
        Aws.config[:credentials] = Aws::Credentials.new(Linecook.config[:aws][:access_key], Linecook.config[:aws][:secret_key])
        Aws.config[:region] = 'us-east-1'
        Aws::Route53::Client.new
      end
    end
  end
end
