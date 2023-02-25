#!/usr/bin/env ruby
require 'csv'
require 'json'
require 'pry'
require 'net/http'

TMB_GUILD_URL     = ENV.fetch('TMB_GUILD_URL')
RAID_GROUP        = ENV.fetch('TMB_GUILD_GROUP_NAME')
OKAY_ALTS         = ENV.fetch('TMB_OKAY_ALTS').split(',')
WARCRAFT_LOGS_KEY = ENV.fetch('WARCRAFT_LOGS_KEY')
WARCRAFT_SERVER   = ENV.fetch('WARCRAFT_SERVER')
WARCRAFT_REGION   = ENV.fetch('WARCRAFT_REGION')

ITEM_EXCLUDES = [
  /Runed Orb/,
  /^Pattern:.+/
]

TODAY = Time.now.to_date.freeze
DATA_FILE = ARGV[0].freeze
abort "abort: import file not found >> #{DATA_FILE}" if !DATA_FILE
DATA = JSON.parse(File.open(DATA_FILE).read).freeze

RECEIVED_RECENTLY = 30.freeze
LEVEL_CAP = 80.freeze

def days_ago(date)
  (TODAY - date).to_i
end

class Array
  def median
    sorted = self.sort
    mid = (sorted.length - 1) / 2.0
    (sorted[mid.floor] + sorted[mid.ceil]) / 2.0
  end
end

class Item
  attr_accessor :name, :received_on, :is_offspec

  def received_days_ago
    days_ago(self.received_on)
  end

  def is_valid?
    self.received_days_ago <= RECEIVED_RECENTLY \
      && self.is_offspec == 0
  end
end

class Character
  attr_accessor :valid, :level, :is_alt, :name, :raid_group_name, :received, :attendance

  def initialize(data)
    self.level = data["level"]
    self.is_alt = data["is_alt"]
    self.name = data["name"]
    self.raid_group_name = data["raid_group_name"]
    self.attendance = (data["attendance_percentage"] * 100).round(0)

    self.received = []

    data["received"].each do |r|
      i = Item.new
      i.name = r["name"]
      i.received_on = Date.parse(r["pivot"]["received_at"])
      i.is_offspec = r["pivot"]["is_offspec"]

      self.received << i if i.is_valid?
    end

    self.received.sort_by!(&:received_days_ago).reverse!
  end

  def is_valid?
    return false if self.level != 80 \
      || self.raid_group_name != "Mains" \
      || (self.is_alt != 0 && OKAY_ALTS.include?(self.name))

    true
  end

  def loot_from(date)
    self.received.select { |r| r.received_on == date }
  end

  def max_parse
    get_parses if @max_parse.nil?
    @max_parse
  end

  # def med_parse
  #   get_parses if @med_parse.nil?
  #   @med_parse
  # end

  def warcraft_logs_endpoint
    [ "https://classic.warcraftlogs.com:443/v1/parses/character",
      self.name, WARCRAFT_SERVER, WARCRAFT_REGION,
      "?api_key=" + WARCRAFT_LOGS_KEY
    ].join("/")
  end

  def get_parse_for_character
    uri  = URI(warcraft_logs_endpoint)
    res  = Net::HTTP.get(uri)
    data = JSON.parse(res)
    data.reject! { |h| h["size"] != 25 }
  end

  def get_parses
    data = get_parse_for_character
    data.sort_by! { |e| e["percentile"] }.reverse!

    # top for each fight
    parses = {}
    data.each do |e|
      boss = e["encounterName"]
      parses[boss] = [] unless parses.has_key?(boss)

      parses[boss] << e["percentile"]
    end

    # medians = {}
    # parses.each do |k, v|
    #   medians[k] = v.median
    # end

    highest = {}
    parses.each do |k, v|
      highest[k] = v.sort.reverse.first
    end

    # avg_of_medians = medians.values.sum(0.0)/medians.values.size
    avg_of_highest = highest.values.sum(0.0)/highest.values.size

    @max_parse = avg_of_highest.round(2)
    # @med_parse = avg_of_medians.round(2)
  rescue => e
    puts " > Warning: Couldn't fetch parse for #{self.name}"
    puts " >   ERROR: \"#{e}\""
    0.0
  end
end

def generate_loot_by_character_and_date_csv
  file_out = "filtered-#{TODAY.to_s}.csv"
  characters = []
  uniq_dates = []
  DATA.each do |char|
    c = Character.new(char)
    characters << c if c.is_valid?

    c.received.each do |i|
      unless uniq_dates.include?(i.received_on)
        uniq_dates << i.received_on
      end
    end
    c.received.uniq!(&:name)
    c.received.reject! do |i|
      found = false
      ITEM_EXCLUDES.each do |iex|
        if i.name.match(iex)
          found = true
          break
        end
      end
      found
    end
  end

  uniq_dates.sort!.reverse!

  header = []
  header << "Name"
  header << "Attendance (%)"
  header << "Item #"
  header << "Parse"
  uniq_dates.each do |date|
    header << "#{date.to_s} (#{days_ago(date)}d)"
  end

  rows = [header]
  characters.each do |c|
    puts "Building data for #{c.name}"
    row = []
    row << c.name
    row << c.attendance
    row << c.received.size
    row << c.max_parse

    uniq_dates.each do |d|
      i = c.loot_from(d).map { |i| i.name }.join("\n")

      i = "-" if i == ""
      row << i
    end

    rows << row
  end

  csv = rows.map { |r| r.to_csv(force_quotes: true) }.join

  IO.write(file_out, csv)
end

generate_loot_by_character_and_date_csv
