require 'sinatra'
require 'open-uri'
require 'line/bot'
require 'net/http'
require 'tempfile'
require 'nokogiri'
require 'rest-client'
require 'cgi'
require 'json'

def client
  @client ||= Line::Bot::Client.new do |config|
    config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
    config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
  end
end

GREETINGS = ['您好', 'Hola', 'नमस्ते', 'Namaste', 'Olá', '今日は', 'Hallo', 'Guten Tag', 'Bonjour', 'Salut', 'Merhaba', 'Ciao', 'สวัสดี', 'Chào bạn']
def bot_respond_to(message, user_name)
#   return '' unless message.downcase.include?('koko') # Only answer to messages with 'koko'

  if message.downcase.match?(/(hello|hi|yo|heyo|hey).*/)
    # respond if a user says hello
    "#{GREETINGS.sample} #{user_name}, how are you doing?"
  elsif message.downcase.match?(/(hungry|starving|dinner|eat|lunch|food).*/)
    # respond if user is ready
    suggest_meal_idea
  elsif message.end_with?('?')
    # respond if a user asks a question
    "Hmm..good question, #{user_name}. I actually looked that up and here is the top result: #{search_that(message)}.\nGood luck!"
  else
    ['Oh, I did not know that.', 'Great to hear that.', 'Interesting.', 'Cool cool cool'].sample
  end
end

WAYS_TO_COOK_VEG = ['Grilled', 'Sautéd', 'Roasted', 'Stir-fried', 'Deep-fried', 'Blanched', 'Steamed', 'Boiled']
WAYS_TO_COOK_PROTEIN = ['Stewed', 'Curried', 'Baked', 'Mashed', 'Roasted', 'Canned', 'Braised', 'Fried', 'Sprouted']
SAUCE_BASE = ['Tomato', 'Coconut', 'Creamy', 'Lemony', 'Soupy', 'Spicy Tahini', 'Burritos with', 'Cheesy', 'Chili', 'Buddha Bowl with']
VEGETABLES = %w[Acorn-squash  Alfalfa  Anise  Artichoke  Arugula  Asparagus  Aubergine  Banana-squash  Basil  Bean-sprouts  Beet  Beetroot  Bell-pepper  Bok-choy  Broccoflower  Broccoli  Brussels-sprouts  Butternut-squash  Cabbage  Calabrese  Capsicum  Caraway  Carrot  Cauliflower  Cayenne-pepper  Celeriac  Celery  Chamomile  Chard  Chili-pepper  Chives  Cilantro  Collard-greens  Corn  Corn-salad  Courgette  Cucumber  Daikon  Delicata  Dill  Eggplant  Endive  Fennel  Fiddleheads  Frisee  fungus  Garlic  Gem-squash  Ginger  Grain  Green-beans  Green-onion  Green-pepper  Habanero  Herbs  Horseradish  Hubbard-squash  Jalapeno  Jerusalem-artichoke  Jicama  Kale  Kohlrabi  Lavender  Leek  Lemon-Grass  Lettuce  Maize  Mangel-wurzel  Mangetout  Marjoram  Marrow  Mushrooms  Mustard-greens  Nettles  New-Zealand-spinach  Okra  Onion  Oregano  Paprika  Parsley  Parsley  Parsnip  Patty-pans  Peppers  Pimento  Plant  Potato  Pumpkin  Purple-Salsify  Radicchio  Radish  Red-pepper  Rhubarb  Root-vegetables  Rosemary  Rutabaga  Sage  Salsify  Scallion  Shallot  Skirret  Snap-peas  Spaghetti-squash  Spinach  Spring-onion  Squash  Squashes  Swede  Sweet-potato  Sweetcorn  Tabasco-pepper  Taro  Tat-soi  Thyme  Tomato  Tubers  Turnip  Wasabi  Water-chestnut  Watercress  White-radish  Yam  Zucchini]
PROTEINS = %w[Edamame Tofu Tempeh Quinoa Amaranth Adzuki-bean Broad-bean Faba-(Fava)-bean Bell-bean Field-bean Windsorbean Horsebean Tickbean Pigeon-bean Vetch Kidney-bean Habichuela Snap-bean Chick-pea Bengal-gram Calvance-pea Chestnut-bean Dwarf-pea Garbanza Garbanzo-bean Garbanzos Gram Gram-pea Yellow-gram Cowpea Asparagus-bean Black-eyed-pea Black-eyed-bean Crowder-pea Field-pea Southern-pea Frijole Paayap Guar-bean Cluster-bean Hyacinth-bean Bonavist Bataw Lablab Lentil Lima-bean Butter-bean Patani Lupin Lupine Sweet-lupin White-lupin Blue-lupin Yellow-lupin Andean-lupin Pearl-lupin Wild-lupin Mung-bean Mungo Pea Dry-pea Podded-pea Chicharo Peanut Groundnut Earth-nut Mani Runner-peanut Soybean Tepary-bean]

def suggest_meal_idea
  vegetable = VEGETABLES.sample
  protein = PROTEINS.sample
  sauce = SAUCE_BASE.sample
  "How about #{sauce} #{WAYS_TO_COOK_PROTEIN.sample} #{protein} with #{WAYS_TO_COOK_VEG.sample} #{vegetable}?"
end

def search_that(message)
  json = RestClient.get(URI.escape("https://api.duckduckgo.com/?q=#{message}&format=json&pretty=1"))
  text = JSON.parse(json)['RelatedTopics'].first['Text']
  url = JSON.parse(json)['RelatedTopics'].first['FirstURL']
  text + url
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
        bot_respond_to(event.message['text'], user_name),
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
