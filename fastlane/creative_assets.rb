# Uploads the product page header and search result assets to the app's Asset Library and places them on an App
# Store version's localization (App Store Connect API; fastlane's deliver doesn't know these assets yet).
# Flow: reserve the asset, PUT its parts to the upload operations, mark it uploaded, wait for processing, then replace
# the version's placement of that type (one each). Placement types and specs come from /v1/appAssetLibraryRefData.
require "jwt"
require "openssl"
require "net/http"
require "json"

module CreativeAssets
  API = "https://api.appstoreconnect.apple.com"

  class Client
    def initialize(key_id:, issuer_id:, key_path:)
      @key = OpenSSL::PKey::EC.new(File.read(File.expand_path(key_path)))
      @key_id = key_id
      @issuer_id = issuer_id
    end

    def token
      now = Time.now.to_i
      JWT.encode({ iss: @issuer_id, iat: now, exp: now + 900, aud: "appstoreconnect-v1" }, @key, "ES256", { kid: @key_id })
    end

    def request(method, path, body = nil)
      uri = URI(path.start_with?("http") ? path : "#{API}#{path}")
      req = Net::HTTP.const_get(method.capitalize).new(uri)
      req["Authorization"] = "Bearer #{token}"
      if body
        req["Content-Type"] = "application/json"
        req.body = JSON.generate(body)
      end
      res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 120) { |http| http.request(req) }
      parsed = res.body.to_s.empty? ? {} : JSON.parse(res.body)
      raise "#{method.upcase} #{path} -> #{res.code}: #{JSON.generate(parsed['errors'] || parsed)[0, 800]}" unless res.code.start_with?("2")
      parsed
    end
  end

  # kind: :image or :video. Returns the asset's id once Apple has processed it.
  def self.upload(client, app_id:, path:, kind:, log:)
    type = kind == :video ? "appAssetLibraryVideos" : "appAssetLibraryImages"
    size = File.size(path)
    reserved = client.request(:post, "/v1/#{type}", { data: {
      type: type,
      attributes: { category: "CREATIVE_ASSETS", fileName: File.basename(path), fileSize: size },
      relationships: { assetLibrary: { data: { type: "appAssetLibraries", id: app_id } } }
    } })["data"]
    id = reserved["id"]
    log.call("reserved #{File.basename(path)} (#{type} #{id})")
    File.open(path, "rb") do |file|
      (reserved.dig("attributes", "uploadOperations") || []).each do |op|
        file.seek(op["offset"])
        uri = URI(op["url"])
        put = Net::HTTP.const_get(op["method"].capitalize).new(uri)
        (op["requestHeaders"] || []).each { |h| put[h["name"]] = h["value"] }
        put.body = file.read(op["length"])
        res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 300) { |http| http.request(put) }
        raise "upload part at #{op['offset']} -> #{res.code}" unless res.code.start_with?("2")
      end
    end
    client.request(:patch, "/v1/#{type}/#{id}", { data: {
      type: type, id: id, attributes: { uploaded: true }
    } })
    log.call("uploaded #{File.basename(path)}, waiting for processing")
    120.times do
      attributes = client.request(:get, "/v1/#{type}/#{id}")["data"]["attributes"]
      state = attributes["state"].to_s
      raise "#{File.basename(path)} failed processing: #{state} #{attributes['stateDetails']}" if state.match?(/FAIL|INVALID|REJECT/)
      # Still on its way: awaiting the upload, uploading or processing. Anything else is settled.
      unless state.match?(/AWAITING|UPLOADING|PROCESS/) || state.empty?
        log.call("#{File.basename(path)}: #{state}")
        return id
      end
      sleep 10
    end
    raise "#{File.basename(path)} still processing after 20 minutes"
  end

  # Replaces the localization's placement of this type with the asset.
  def self.place(client, localization_id:, placement_type:, asset_id:, kind:, log:)
    existing = client.request(:get, "/v1/appStoreVersionLocalizations/#{localization_id}/placements?limit=200")["data"]
    existing.select { |p| p.dig("attributes", "placementType") == placement_type }.each do |old|
      client.request(:delete, "/v1/appAssetLibraryPlacements/#{old['id']}")
      log.call("removed the old #{placement_type}")
    end
    asset = kind == :video ? { video: { data: { type: "appAssetLibraryVideos", id: asset_id } } }
                           : { image: { data: { type: "appAssetLibraryImages", id: asset_id } } }
    client.request(:post, "/v1/appAssetLibraryPlacements", { data: {
      type: "appAssetLibraryPlacements",
      attributes: { placementType: placement_type, placementGroup: "DEFAULT_PROFILE" },
      relationships: { appStoreVersionLocalization: { data: { type: "appStoreVersionLocalizations", id: localization_id } } }
        .merge(asset)
    } })
    log.call("placed #{placement_type}")
  end

  def self.localization_id(client, app_id:, version:, locale:)
    versions = client.request(:get, "/v1/apps/#{app_id}/appStoreVersions?filter[versionString]=#{version}")["data"]
    raise "no App Store version #{version}" if versions.empty?
    locs = client.request(:get, "/v1/appStoreVersions/#{versions.first['id']}/appStoreVersionLocalizations")["data"]
    loc = locs.find { |l| l.dig("attributes", "locale") == locale } or raise "version #{version} has no #{locale}"
    loc["id"]
  end
end
