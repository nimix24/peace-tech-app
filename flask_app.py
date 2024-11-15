from flask import Flask, request, jsonify
import boto3
import os

app = Flask(__name__)

# Initialize SQS client with environment variable QUEUE_URL
sqs = boto3.client('sqs', region_name='us-west-2')
queue_url = os.getenv('QUEUE_URL')

@app.route('/send', methods=['POST'])
def send_message():
    try:
        # Extract message from request
        message_body = request.json.get('message')

        if not message_body:
            return jsonify({'error': 'Message body is required'}), 400

        # Send message to SQS
        print(message_body)
        response = sqs.send_message(QueueUrl=queue_url,MessageBody=message_body)
        print(response)
        return jsonify({
            'MessageId': response['MessageId'],
            'Status': 'Message sent successfully'
        })

    except Exception as e:
        print(e)
        return jsonify({'error': str(e)}), 500

@app.route('/receive', methods=['GET'])
def receive_message():
    try:
        # Receive message from SQS
        response = sqs.receive_message(
            QueueUrl=queue_url,
            MaxNumberOfMessages=10,  # Get up to 10 messages
            WaitTimeSeconds=10  # Long-polling for up to 10 seconds
            # VisibilityTimeout=5  # Set a shorter visibility timeout
        )
        messages = response.get('Messages', [])

        if not messages:
            return jsonify({'Status': 'No messages available in the queue'}), 200

        message = messages[0]
        message_body = message['Body']
        receipt_handle = message['ReceiptHandle']

        # Delete the message after processing
        sqs.delete_message(
            QueueUrl=queue_url,
            ReceiptHandle=receipt_handle
        )

        return jsonify({
            'Message': message_body,
            'Status': 'Message received and deleted from queue',
        }), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500

# Run the Flask app
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)