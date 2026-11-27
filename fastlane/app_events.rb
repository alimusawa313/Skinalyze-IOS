# Creates or updates the App Store in-app events in fastlane/metadata/events.json (App Store Connect API; fastlane has
# no action for events). Per event: the event (badge, purpose, priority, deep link, schedule in every territory the
# app is sold in), its en-US text, and the two videos from docs/appstore/events (<media>-card.mp4 for the event card,
# <media>-details.mp4 for the details page). Re-runnable: an event is matched by its reference name, and a video that
# is already uploaded under the same file name is kept. Nothing is submitted for review.
require_relative "creative_assets"

module AppEvents
  ASSET_TYPES = { "card" => "EVENT_CARD", "details" => "EVENT_DETAILS_PAGE" }.freeze
  EDITABLE_STATES = %w[DRAFT REJECTED].freeze

  def self.sync(client, app_id:, events_file:, media_dir:, log:)
    events = JSON.parse(File.read(events_file, encoding: "UTF-8"))
    territories = sold_territories(client, app_id)
    log.call("#{territories.size} territories")
    existing = client.request(:get, "/v1/apps/#{app_id}/appEvents?limit=50")["data"]
    events.map do |spec|
      event = existing.find { |e| e.dig("attributes", "referenceName") == spec["referenceName"] }
      # Once an event is in review or live, App Store Connect only allows schedule and priority changes: leave it be.
      state = event&.dig("attributes", "eventState")
      if event && !EDITABLE_STATES.include?(state)
        log.call("#{spec['referenceName']}: #{state}, left as it is")
        next event["id"]
      end
      event_id = event ? update_event(client, event["id"], spec, territories) : create_event(client, app_id, spec, territories)
      log.call("#{spec['referenceName']}: event #{event ? 'updated' : 'created'} (#{event_id})")
      localization = upsert_localization(client, event_id, spec["en-US"])
      ASSET_TYPES.each do |format, type|
        path = File.join(media_dir, "#{spec['media']}-#{format}.mp4")
        upload_video(client, localization, path, type, spec["previewFrame"], log)
      end
      event_id
    end
  end

  # Every territory the app is on sale in (Skinalyze leaves out China mainland).
  def self.sold_territories(client, app_id)
    availability = client.request(:get, "/v1/apps/#{app_id}/appAvailabilityV2")["data"]
    ids = []
    url = "/v2/appAvailabilities/#{availability['id']}/territoryAvailabilities?limit=200&include=territory"
    while url
      page = client.request(:get, url)
      page["data"].each do |row|
        ids << row.dig("relationships", "territory", "data", "id") if row.dig("attributes", "available")
      end
      url = page.dig("links", "next")
    end
    ids.compact.sort
  end

  def self.event_attributes(spec, territories)
    {
      referenceName: spec["referenceName"], badge: spec["badge"], purpose: spec["purpose"], priority: spec["priority"],
      deepLink: spec["deepLink"], purchaseRequirement: spec.fetch("purchaseRequirement", "NO_COST_ASSOCIATED"),
      primaryLocale: "en-US",
      territorySchedules: [{ territories: territories, publishStart: spec["publishStart"],
                             eventStart: spec["eventStart"], eventEnd: spec["eventEnd"] }]
    }
  end

  def self.create_event(client, app_id, spec, territories)
    client.request(:post, "/v1/appEvents", { data: {
      type: "appEvents", attributes: event_attributes(spec, territories),
      relationships: { app: { data: { type: "apps", id: app_id } } }
    } })["data"]["id"]
  end

  def self.update_event(client, id, spec, territories)
    client.request(:patch, "/v1/appEvents/#{id}", { data: {
      type: "appEvents", id: id, attributes: event_attributes(spec, territories)
    } })
    id
  end

  def self.upsert_localization(client, event_id, text)
    locs = client.request(:get, "/v1/appEvents/#{event_id}/localizations")["data"]
    loc = locs.find { |l| l.dig("attributes", "locale") == "en-US" }
    attributes = { name: text["name"], shortDescription: text["shortDescription"], longDescription: text["longDescription"] }
    if loc
      client.request(:patch, "/v1/appEventLocalizations/#{loc['id']}", { data: {
        type: "appEventLocalizations", id: loc["id"], attributes: attributes
      } })
      loc["id"]
    else
      client.request(:post, "/v1/appEventLocalizations", { data: {
        type: "appEventLocalizations", attributes: attributes.merge(locale: "en-US"),
        relationships: { appEvent: { data: { type: "appEvents", id: event_id } } }
      } })["data"]["id"]
    end
  end

  # Replaces the localization's video of this type unless the same file is already there.
  def self.upload_video(client, localization, path, type, preview_frame, log)
    name = File.basename(path)
    clips = client.request(:get, "/v1/appEventLocalizations/#{localization}/appEventVideoClips")["data"]
    same_type = clips.select { |c| c.dig("attributes", "appEventAssetType") == type }
    if same_type.any? { |c| c.dig("attributes", "fileName") == name && c.dig("attributes", "fileSize") == File.size(path) }
      log.call("#{name}: already uploaded")
      return
    end
    same_type.each { |old| client.request(:delete, "/v1/appEventVideoClips/#{old['id']}") }
    reserved = client.request(:post, "/v1/appEventVideoClips", { data: {
      type: "appEventVideoClips",
      attributes: { fileName: name, fileSize: File.size(path), appEventAssetType: type, previewFrameTimeCode: preview_frame },
      relationships: { appEventLocalization: { data: { type: "appEventLocalizations", id: localization } } }
    } })["data"]
    File.open(path, "rb") do |file|
      reserved.dig("attributes", "uploadOperations").each do |op|
        file.seek(op["offset"])
        uri = URI(op["url"])
        put = Net::HTTP.const_get(op["method"].capitalize).new(uri)
        (op["requestHeaders"] || []).each { |h| put[h["name"]] = h["value"] }
        put.body = file.read(op["length"])
        res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 300) { |http| http.request(put) }
        raise "#{name}: upload part at #{op['offset']} -> #{res.code}" unless res.code.start_with?("2")
      end
    end
    client.request(:patch, "/v1/appEventVideoClips/#{reserved['id']}", { data: {
      type: "appEventVideoClips", id: reserved["id"], attributes: { uploaded: true }
    } })
    wait_for_video(client, reserved["id"], name, log)
  end

  def self.wait_for_video(client, id, name, log)
    90.times do
      state = client.request(:get, "/v1/appEventVideoClips/#{id}")["data"]["attributes"]["videoDeliveryState"] || {}
      case state["state"]
      when "COMPLETE"
        log.call("#{name}: processed")
        return
      when "FAILED"
        raise "#{name} failed processing: #{state['errors'].inspect}"
      end
      sleep 10
    end
    raise "#{name} still processing after 15 minutes"
  end
end
