from flask import Flask, request, jsonify
import requests
import hashlib
import os

app = Flask(__name__)

# In-memory message storage
messages = []

# Service URLs
GENAI_SERVICE_URL = f"http://{os.getenv('GENAI_SERVICE_IP')}:5001/generate-greeting"
DYNAMODB_SERVICE_URL = f"http://{os.getenv('DYNAMODB_SERVICE_IP')}:5002/save-message"
SENTIMENT_SERVICE_URL = f"http://{os.getenv('SENTIMENT_SERVICE_IP')}:5003/analyze-sentiment"

# GENAI_SERVICE_URL = f"http://127.0.0.1:5001/generate-greeting"
# DYNAMODB_SERVICE_URL = f"http://127.0.0.1:5002/save-message"
# SENTIMENT_SERVICE_URL = f"http://127.0.0.1:5003/analyze-sentiment"

# Initialize SQS client with environment variable QUEUE_URL
# sqs = boto3.client('sqs', region_name='us-west-2')
# queue_url = os.getenv('QUEUE_URL')

@app.route('/')
def index():
    return '<h1>Greetings viewer. You Need To Go To /receive.  </h1>'

@app.route('/send', methods=['POST'])
def send_message():
    try:
        # Extract message from request
        language = request.json.get('language', 'english').lower()
        print("language is: ", language)

        if not language:
            return jsonify({'error': 'Language is required'}), 400

        # Send message to SQS
        # print(message_body)
        # response = sqs.send_message(QueueUrl=queue_url,MessageBody=message_body)
        # print(response)
        # return jsonify({
         #   'MessageId': response['MessageId'],
         #   'Status': 'Message sent successfully'
        # })

        # Call GenAI Service to generate a greeting
        # try:
        #     print("LINE 49 - Calling genai_response")
        #     genai_response = requests.post(GENAI_SERVICE_URL, json={"language": language})
        #     print ("genai_response is:" + genai_response.text)
        #     if genai_response.status_code != 200:
        #         return jsonify({'error': 'Failed to fetch greeting from GenAI service'}), 500
        # except Exception as e:
        #     print("Error occurred calling to genai_response:", str(e))
        #     return jsonify({'error response from genai_response': str(e)}), 500

        #genai_data = genai_response.json()
        #greeting = genai_data.get('greeting', '')
        #print("greeting is: " +greeting)
        greeting = {
            "greeting": "Hello there, I am glad to meet you!",
            "language": "english"
        }

        #if not greeting:
         #   return jsonify({'error': 'No greeting received from GenAI service'}), 500

        # Store the greeting and language in the in-memory list
        #messages.append(genai_data)
        messages.append(greeting)
        print ("messages.append(genai_data)--> " ,messages)

        # Call Sentiment Analysis Service
        sentiment_response = requests.post(SENTIMENT_SERVICE_URL, json={"text": greeting})
        if sentiment_response.status_code != 200:
            return jsonify({'error': 'Failed to analyze sentiment'}), 500

        sentiment = sentiment_response.json()
        print ("sentiment is: " , sentiment)

        # Prepare the data to save in DynamoDB
        # response_message = {
        #     "greeting": greeting,
        #     "language": language,
        #     "sentiment": sentiment,
        # }
        response_message = {
            "greeting": "hello how are you ",
            "language": "english",
            "sentiment": "0.78",
        }
        #response_message['id'] = str(hashlib.md5(response_message['greeting'].encode()).hexdigest())

        # Call DynamoDB Service to save the data
        print ("about to save --> ", response_message)
        save_response = requests.post(DYNAMODB_SERVICE_URL, json=response_message)
        print ("save_response.status_code", save_response.status_code)

        if save_response.status_code == 404:
            return jsonify({'error': "The table doesn't exist. Please create the table and try again."}), 404

        if save_response.status_code != 200:
            return jsonify({'error': 'Failed to save data to DynamoDB'}), 500

       # return jsonify({"Status": "Message sent successfully and saved in DB", "Response": response_message}), 200
        return jsonify({"Status": "Message sent successfully and saved in DB", "Response": response_message}), 200

    except Exception as e:
        print("Error occurred:", str(e))
        return jsonify({'error': str(e)}), 500

@app.route('/receive', methods=['GET'])
def receive_message():
    try:
        # Receive message from SQS
        # response = sqs.receive_message(QueueUrl=queue_url,MaxNumberOfMessages=10,WaitTimeSeconds=10
            # VisibilityTimeout=5  # Set a shorter visibility timeout)
        # messages = response.get('Messages', [])

        if not messages:
            return jsonify({'Status': 'No messages available in the queue'}), 200

        # Display all stored messages and clear the list
        received_messages = messages.copy()
        messages.clear()

        return jsonify({'Messages': received_messages, 'Status': 'Messages received and deleted from queue'}), 200

        # message = messages[0]
        # message_body = message['Body']
        # receipt_handle = message['ReceiptHandle']

        # Delete the message after processing
      #  sqs.delete_message(QueueUrl=queue_url, ReceiptHandle=receipt_handle)

        # return jsonify({
        #    'Message': message_body,
        #    'Status': 'Message received and deleted from queue',}), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500

# Run the Flask app
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=6000)