# frozen_string_literal: true

require 'bundler/setup'
require 'dotenv/load'
require 'google/apis/calendar_v3'
require 'slack-ruby-client'
require 'time'

# Configurations
Slack.configure do |config|
  config.token = ENV['SLACK_API_TOKEN']
  raise 'Missing SLACK_API_TOKEN!' unless config.token
end
CURRENT_TIME = DateTime.now.new_offset(0)

# Services
class TimeOffEventsFetcher
  def call(time_min, time_max)
    response = calendar_service.list_events(
      pto_calendar_id,
      single_events: true,
      order_by: 'startTime',
      time_min: time_min,
      time_max: time_max
    )

    hash = {}
    response.items.each do |event|
      name, pto_type = *event.summary.split(' on ')
      start_time = (event.start.date || event.start.date_time).strftime('%m/%d')
      end_time = (event.end.date || event.end.date_time).strftime('%m/%d')
      hash[name] = [] unless hash.key?(name)
      hash[name] << {
        pto_type: pto_type,
        start_time: start_time,
        end_time: end_time
      }
    end
    puts "Fetched #{hash.size} time off events"
    hash
  rescue Google::Apis::Error => e
    puts "Google::Apis::Error: #{e.message}"
  end

  private

  def calendar_service
    @calendar_service ||=
      Google::Apis::CalendarV3::CalendarService.new.tap do |service|
        service.key = ENV['GOOGLE_API_KEY']
        raise 'Missing GOOGLE_API_KEY!' unless service.key
      end
  end

  def pto_calendar_id
    ENV['PTO_CALENDAR_ID']
  end
end

class SlackNotifier
  def initialize(event_hash)
    @event_hash = event_hash
  end

  def call(channel)
    response = client.chat_postMessage(
      channel: channel,
      text: mrkdwn_text,
      mrkdwn: true,
    )
    if response.ok
      puts "Message successfully sent to #{channel}"
    else
      puts "Failed to send message: #{response.error}"
    end
  rescue Slack::Web::Api::Errors::SlackError => e
    puts "Error sending message: #{e.message}"
  end

  private

  attr_reader :event_hash

  def mrkdwn_text
    text = "-----\n:palm_tree: #{CURRENT_TIME.strftime('%Y/%m/%d')} Approved PTO :palm_tree:"
    event_hash.sort_by { |name, _| name }.each do |name, events|
      events.each do |event|
        text += "\n*#{name}*: _#{event[:pto_type]} (#{event_duration(event[:start_time], event[:end_time])})_"
      end
    end
    text
  end

  def event_duration(start_time, end_time)
    start_time == end_time ? start_time : "#{start_time}-#{end_time}"
  end

  def client
    @client ||= Slack::Web::Client.new
  end
end

# Execution
time_min = CURRENT_TIME.strftime('%Y-%m-%dT00:00:00%z')
time_max = CURRENT_TIME.strftime('%Y-%m-%dT23:59:59%z')
event_hash = TimeOffEventsFetcher.new.call(time_min, time_max)

SlackNotifier.new(event_hash).call('#internal-time-off-notifications')
