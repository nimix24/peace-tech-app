import boto3
import json

def get_secret(secret_id):
    client = boto3.client('secretsmanager', region_name='us-west-2')

    try:
        response = client.get_secret_value(SecretId=secret_id)
        secret_data = json.loads(response['SecretString'])
        return secret_data
    except Exception as e:
        #print(json.dumps({"error": str(e)}))
        return {"error": str(e)}
        #sys.exit(1)

if __name__ == "__main__":

    secret_name = "aws/credentials"
    try:
        secret_content = get_secret(secret_name)
        print(json.dumps(secret_content))
    except Exception as e:
        print(json.dumps({"error": str(e)}))

