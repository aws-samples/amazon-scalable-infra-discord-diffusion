import requests
import os
import boto3
import json

APPLICATION_ID = os.environ.get("APPLICATION_ID")
ssm = boto3.client('ssm')

def deleteCommand(command_id, application_id, headers):
    ## Deletes a command from the command tree. You may need to use getCommands and verify the 'id'
    # EX: r = deleteCommand(1018006376578023465, APPLICATION_ID, headers)
    url = f'https://discord.com/api/v10/applications/{application_id}/commands/{command_id}'
    r = requests.delete(url, headers=headers)
    validateRequest(r)
    print("Deleted Command id" + command_id)
    return r

def getCommands(application_id, headers):
    ## Gets command names and numbers from tree.
    url = f'https://discord.com/api/v10/applications//{application_id}/commands'
    r = requests.get(url, headers=headers)
    validateRequest(r)
    print(r.text)
    return r
    
def updateCommands(file_path, application_id, headers):
    ## Updates the command tree with whatever is in the json file
    with open(file_path, 'r') as f:
        command_json = json.loads(f.read())

    url = f"https://discord.com/api/v10/applications/{APPLICATION_ID}/commands"
    r = requests.post(url, headers=headers, json=command_json)
    validateRequest(r)
    return r

def validateRequest(r):
    if not r.ok:
        print("Failure")
        raise Exception(r.text)
    else:
        print("Success")
    return

def lambda_handler(event, context):

    DISCORD_TOKEN = ssm.get_parameter(Name='/BOT_TOKEN', WithDecryption=True)['Parameter']['Value']
    # For authorization, you can use either your bot token
    headers = {
        "Authorization": f"Bot {DISCORD_TOKEN}"
    }
    
    r = updateCommands('command_tree.json', APPLICATION_ID, headers)
    # r = getCommands(APPLICATION_ID, headers)
    # r = deleteCommand(1018010467383377964, APPLICATION_ID, headers)
    return