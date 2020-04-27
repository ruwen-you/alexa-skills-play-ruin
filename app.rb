require "sinatra"
require 'sinatra/reloader' if development?

require 'alexa_skills_ruby'
require 'httparty'
require 'iso8601'
require 'httparty'

# ----------------------------------------------------------------------

# Load environment variables using Dotenv. If a .env file exists, it will
# set environment variables from that file (useful for dev environments)
configure :development do
  require 'dotenv'
  Dotenv.load
end

# enable sessions for this project
enable :sessions


# ----------------------------------------------------------------------
#     How you handle your Alexa
# ----------------------------------------------------------------------

class CustomHandler < AlexaSkillsRuby::Handler

  on_intent("GetZodiacHoroscopeIntent") do
    slots = request.intent.slots
    response.set_output_speech_text("Horoscope Text")
    #response.set_output_speech_ssml("<speak><p>Horoscope Text</p><p>More Horoscope text</p></speak>")
    response.set_reprompt_speech_text("Reprompt Horoscope Text")
    #response.set_reprompt_speech_ssml("<speak>Reprompt Horoscope Text</speak>")
    response.set_simple_card("title", "content")
    logger.info 'GetZodiacHoroscopeIntent processed'
  end

  on_intent("HERE") do
    # add a response to Alexa
    response.set_output_speech_text("I've updated your status to Here ")
    # create a card response in the alexa app
    response.set_simple_card("Out of Office App", "Status is in the office.")
    # log the output if needed
    logger.info 'Here processed'
    # send a message to slack
    update_status "HERE"
  end

  on_intent("BE_RIGHT_BACK") do
    # add a response to Alexa
    response.set_output_speech_text("I've updated your status to BE RIGHT BACK ")
    # create a card response in the alexa app
    response.set_simple_card("Out of Office App", "Status is out of the office.")
    # log the output if needed
    logger.info 'BE_RIGHT_BACK processed'
    # send a message to slack
    update_status "BE_RIGHT_BACK"
  end

  on_intent("GONE_HOME") do
    # add a response to Alexa
    response.set_output_speech_text("I've updated your status to GONE HOME ")
    # create a card response in the alexa app
    response.set_simple_card("Out of Office App", "Status is at home.")
    # log the output if needed
    logger.info 'GONE_HOME processed'
    # send a message to slack
    update_status "GONE_HOME"
  end

  on_intent("DO_NOT_DISTURB") do
    # add a response to Alexa
    response.set_output_speech_text("I've updated your status to DO NOT DISTURB ")
    # create a card response in the alexa app
    response.set_simple_card("Out of Office App", "Status is in a meeting.")
    # log the output if needed
    logger.info 'DO_NOT_DISTURB processed'
    # send a message to slack
    update_status "DO_NOT_DISTURB"
  end

  on_intent("AMAZON.HelpIntent") do
    response.set_output_speech_text("You can ask me to tell you the current out of office status by saying current status. You can update your stats by saying tell out of office i'll be right back, i've gone home, i'm busy, i'm here or i'll be back in 10 minutes")
    logger.info 'HelpIntent processed'
  end

end

# ----------------------------------------------------------------------
#     ROUTES, END POINTS AND ACTIONS
# ----------------------------------------------------------------------


get '/' do
  404
end


# THE APPLICATION ID CAN BE FOUND IN THE


post '/incoming/alexa' do
  content_type :json

  handler = CustomHandler.new(application_id: ENV['ALEXA_APPLICATION_ID'], logger: logger)

  begin
    hdrs = { 'Signature' => request.env['HTTP_SIGNATURE'], 'SignatureCertChainUrl' => request.env['HTTP_SIGNATURECERTCHAINURL'] }
    handler.handle(request.body.read, hdrs)
  rescue AlexaSkillsRuby::Error => e
    logger.error e.to_s
    403
  end

end



# ----------------------------------------------------------------------
#     ERRORS
# ----------------------------------------------------------------------



error 401 do
  "Not allowed!!!"
end

def update_status status, duration = nil

	# gets a corresponding message
  message = get_message_for status, duration
	# posts it to slack
  post_to_slack status, message

end

def get_message_for status, duration

	# Default response
  message = "other/unknown"

	# looks up a message based on the Status provided
  if status == "HERE"
    message = ENV['APP_USER'].to_s + " is in the office."
  elsif status == "BACK_IN"
    message = ENV['APP_USER'].to_s + " will be back in #{(duration/60).round} minutes"
  elsif status == "BE_RIGHT_BACK"
    message = ENV['APP_USER'].to_s + " will be right back"
  elsif status == "GONE_HOME"
    message = ENV['APP_USER'].to_s + " has left for the day. Check back tomorrow."
  elsif status == "DO_NOT_DISTURB"
    message = ENV['APP_USER'].to_s + " is busy. Please do not disturb."
  end

	# return the appropriate message
  message

end

def post_to_slack status_update, message

	# look up the Slack url from the env
  slack_webhook = ENV['SLACK_WEBHOOK']

	# create a formatted message
  formatted_message = "*Status Changed for #{ENV['APP_USER'].to_s} to: #{status_update}*\n"
  formatted_message += "#{message} "

	# Post it to Slack
  HTTParty.post slack_webhook, body: {text: formatted_message.to_s, username: "OutOfOfficeBot", channel: "back" }.to_json, headers: {'content-type' => 'application/json'}

end

private
