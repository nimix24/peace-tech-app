import boto3

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb', region_name='us-west-2')
table = dynamodb.Table('example_table')

# Write data
table.put_item(Item={'id': '123', 'name': 'Test Item'})

# Read data
response = table.get_item(Key={'id': '123'})
print(response.get('Item'))
