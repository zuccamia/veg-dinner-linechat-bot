require 'sinatra'
require 'json'
require 'open-uri'
require 'line/bot'
require 'net/http'
require 'tempfile'
require 'nokogiri'
require 'csv'

require_relative 'vegetables'
require_relative 'proteins'

def client
  @client ||= Line::Bot::Client.new do |config|
    config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
    config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
  end
end

def bot_respond_to(message, user_name)
  return '' unless message.downcase.include?('koko') # Only answer to messages with 'koko'

  if message.downcase.match?(/(hello | hi | yo | heyo | hey).*/)
    # respond if a user says hello
    "Hello #{user_name}, how are you doing?"
  elsif message.downcase.match?(/(hungry | starving | no idea | dinner | eat | lunch | food).*/)
    # respond if user is ready
    suggest_meal_idea
  elsif message.downcase.match?(/(no | not yet | nope | nah).*/)
    ['No problem, take your time!', 'Later then', 'Perhaps you are hungry?'].sample
  elsif message.end_with?('?')
    # respond if a user asks a question
    "Hmm..good question, #{user_name}. I actually looked that up and here is the top result: #{search_that(message)}. Good luck!"
  else
    ['Oh, I did not know that.', 'Great to hear that.', 'Interesting.', 'Cool cool cool'].sample
  end
end

WAYS_TO_COOK_VEG = ['Grilled', 'Sautéd', 'Roasted', 'Stir-fried', 'Deep-fried', 'Blanched', 'Steamed', 'Boiled']
WAYS_TO_COOK_PROTEIN = ['Stewed', 'Curried', 'Baked', 'Mashed', 'Roasted', 'Canned', 'Braised', 'Fried', 'Sprouted']
SAUCE_BASE = ['Tomato', 'Coconut', 'Creamy', 'Lemony', 'Soupy', 'Spicy Tahini', 'Burritos with', 'Cheesy', 'Chili', 'Buddha Bowl with']

def suggest_meal_idea
  vegetable = CSV.read(File.join(__dir__, 'vegetables.csv')).sample
  protein = CSV.read(File.join(__dir__, 'proteins.csv')).sample
  "How about #{SAUCE_BASE.sample} #{WAYS_TO_COOK_PROTEIN.sample} #{protein} with #{WAYS_TO_COOK_VEG.sample} #{vegetable}?"
end

def search_that(message)
  ecosia_first_page = Nokogiri::HTML(open("https://www.ecosia.org/search?q=#{message}").read)
  ecosia_first_page.search('.result-title[href]')[0].attribute('href').value
end

def send_bot_message(message, client, event)
  # Log prints
  p 'Bot message sent!'
  p event['replyToken']
  p client

  message = { type: 'text', text: message }
  p message

  client.reply_message(event['replyToken'], message)
  'OK'
end

post '/callback' do
  body = request.body.read

  signature = request.env['HTTP_X_LINE_SIGNATURE']
  unless client.validate_signature(body, signature)
    error 400 do 'Bad Request' end
  end

  events = client.parse_events_from(body)
  events.each do |event|
    p event
    # Focus on the message events (including text, image, emoji, vocal.. messages)
    next if event.class != Line::Bot::Event::Message

    # case event.type
    # when receive a text message
    if event.type == Line::Bot::Event::MessageType::Text
    user_name = ''
    user_id = event['source']['userId']
    response = client.get_profile(user_id)
      if response.class == Net::HTTPOK
        contact = JSON.parse(response.body)
        p contact
        user_name = contact['displayName']
      else
        # Can't retrieve the contact info
        p "#{response.code} #{response.body}"
      end

      if event.message['text'].downcase == 'hello, world'
        # Sending a message when LINE tries to verify the webhook
        send_bot_message(
        'Everything is working!',
        client,
        event
        )
      else
        # The answer mechanism is here!
        send_bot_message(
        bot_answer_to(event.message['text'], user_name),
        client,
        event
        )
      end
    # # when receive an image message
    # when Line::Bot::Event::MessageType::Image
    # response_image = client.get_message_content(event.message['id'])
    # fetch_ibm_watson(response_image) do |image_results|
    #     # Sending the image results
    #     send_bot_message(
    #     "Looking at that picture, the first words that come to me are #{image_results[0..1].join(', ')} and #{image_results[2]}. Pretty good, eh?",
    #     client,
    #     event
    #     )
    #   end
    end
  end
  'OK'
end
