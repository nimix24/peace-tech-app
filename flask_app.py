from flask import Flask, request, jsonify
import boto3
import os

app = Flask(__name__)

# In-memory message storage
messages = []

# Initialize SQS client with environment variable QUEUE_URL
#sqs = boto3.client('sqs', region_name='us-west-2')
#queue_url = os.getenv('QUEUE_URL')

@app.route('/send', methods=['POST'])
def send_message():
    print("Received request:", request.json)
    try:
        # Extract message from request
        message_body = request.json.get('message')
        print("Message body extracted:", message_body)

        if not message_body:
            return jsonify({'error': 'Message body is required'}), 400

        # Send message to SQS
        #print(message_body)
        #response = sqs.send_message(QueueUrl=queue_url,MessageBody=message_body)
        #print(response)
        #return jsonify({
         #   'MessageId': response['MessageId'],
         #   'Status': 'Message sent successfully'
        #})

        # Store the message in the in-memory list
        messages.append(message_body)
        print("Message appended:", messages)
        return jsonify({"Status": "Message sent successfully"}), 200

    except Exception as e:
        print("Error occurred:", str(e))
        return jsonify({'error': str(e)}), 500

@app.route('/receive', methods=['GET'])
def receive_message():
    try:
        # Receive message from SQS
        #response = sqs.receive_message(QueueUrl=queue_url,MaxNumberOfMessages=10,WaitTimeSeconds=10
            # VisibilityTimeout=5  # Set a shorter visibility timeout)
        #messages = response.get('Messages', [])

        if not messages:
            return jsonify({'Status': 'No messages available in the queue'}), 200

        # Display all stored messages and clear the list
        received_messages = messages.copy()
        messages.clear()
        return jsonify({
            'Messages': received_messages,
            'Status': 'Message/s received and deleted from queue'}), 200

        #message = messages[0]
        #message_body = message['Body']
        #receipt_handle = message['ReceiptHandle']

        # Delete the message after processing
      #  sqs.delete_message(QueueUrl=queue_url, ReceiptHandle=receipt_handle)

        #return jsonify({
        #    'Message': message_body,
        #    'Status': 'Message received and deleted from queue',}), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500

# Run the Flask app
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)