import requests
import json
import sys
import uuid
from datetime import datetime
import argparse

def get_falcon_token(client_id, secret):
    url = "https://api.crowdstrike.com/oauth2/token"
    data = {
        "client_id": client_id,
        "client_secret": secret
    }
    headers = {
        "Content-Type": "application/x-www-form-urlencoded",
        "accept": "application/json"
    }
    
    response = requests.post(url, data=data, headers=headers)
    response_json = response.json()
    
    if 'access_token' not in response_json:
        raise Exception("Failed to get access token")
        
    return response_json['access_token']

def get_packages(token, image_digest):
    url = f"https://api.crowdstrike.com/container-security/combined/packages/v1"
    params = {
        "filter": f'image_digest:"{image_digest}"',
        "only_zero_day_affected": "false",
        "limit": 100
    }
    headers = {
        "Authorization": f"Bearer {token}",
        "accept": "application/json"
    }
    
    response = requests.get(url, params=params, headers=headers)
    if response.status_code != 200:
        raise Exception(f"Failed to get packages: {response.status_code}")
    
    return response.json()

def convert_to_cyclonedx(json_data):
    bom = {
        "bomFormat": "CycloneDX",
        "specVersion": "1.4",
        "serialNumber": f"urn:uuid:{uuid.uuid4()}",
        "version": 1,
        "metadata": {
            "timestamp": datetime.utcnow().isoformat(),
            "tools": [
                {
                    "vendor": "CrowdStrike",
                    "name": "CrowdStrike Container Security",
                    "version": "1.0"
                }
            ]
        },
        "components": []
    }
    
    for resource in json_data["resources"]:
        vulnerabilities = []
        for vuln in resource.get("vulnerabilities", []):
            vulnerabilities.append({
                "id": vuln["cveid"],
                "source": {
                    "name": "NVD",
                    "url": f"https://nvd.nist.gov/vuln/detail/{vuln['cveid']}"
                },
                "ratings": [{
                    "source": {"name": "CrowdStrike"},
                    "severity": vuln["severity"].lower(),
                }],
                "description": vuln["description"],
                "recommendation": "; ".join(vuln.get("fix_resolution", []))
            })
        
        component = {
            "type": "library",
            "name": resource["package_name_version"].split()[0],
            "version": resource["package_name_version"].split()[-1],
            "purl": f"pkg:{resource['type'].lower()}/{resource['package_name_version'].split()[0]}@{resource['package_name_version'].split()[-1]}",
        }
        
        if vulnerabilities:
            component["vulnerabilities"] = vulnerabilities
            
        bom["components"].append(component)

    return bom

def main():
    parser = argparse.ArgumentParser(description='Convert CrowdStrike vulnerability data to CycloneDX format')
    parser.add_argument('--client-id', required=True, help='CrowdStrike API client ID')
    parser.add_argument('--secret', required=True, help='CrowdStrike API secret')
    parser.add_argument('--image-digest', required=True, help='Image digest to query')
    parser.add_argument('--output', default='cyclonedx-bom.json', help='Output file name (default: cyclonedx-bom.json)')
    
    args = parser.parse_args()
    
    try:
        print("Getting vulnerability data...")
        token = get_falcon_token(args.client_id, args.secret)
        crowdstrike_data = get_packages(token, args.image_digest)
        
        print("Converting to CycloneDX format...")
        cyclonedx_bom = convert_to_cyclonedx(crowdstrike_data)
        
        with open(args.output, 'w') as f:
            json.dump(cyclonedx_bom, f, indent=2)
            
        print(f"Successfully created CycloneDX BOM: {args.output}")
        
    except Exception as e:
        print(f"Error: {str(e)}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
