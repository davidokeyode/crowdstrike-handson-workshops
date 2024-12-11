


### Exercise 1 - 

1. **SSH into the Linux VM**

2. **Check that the OS and processor architecture are supported**
```
lsb_release -a
dpkg --print-architecture
```

3. **Prepare the Linux VM for the sensor installation**
```
sudo apt update -y
sudo apt-get install libnl-3-200 libnl-genl-3-200 -y
```

4. **Deploy the sensor**
```
curl -o falcon-sensor_7.18.0-17106_amd64.deb https://dostoresec.blob.core.windows.net/crowdstrike/falcon-sensor_7.18.0-17106_amd64.deb

sudo dpkg -i <installer_filename>
```

5. **Set the CID and verify that it is set**
```
export FALCON_CLIENT_ID=YOUR_CLIENT_ID
export FALCON_CLIENT_SECRET=YOUR_CLIENT_SECRET

FALCON_TOKEN=$(curl -X POST "https://api.crowdstrike.com/oauth2/token" \
 -H "accept: application/json" \
 -H "Content-Type: application/x-www-form-urlencoded" \
 -d "client_id=$FALCON_CLIENT_ID&client_secret=$FALCON_CLIENT_SECRET" \
 | jq -r '.access_token')

export FALCON_CID=$(curl -X GET "https://api.crowdstrike.com/sensors/queries/installers/ccid/v1" -H "accept: application/json" -H "authorization: Bearer $FALCON_TOKEN" | jq -r '.resources[0]')

echo $FALCON_CID

sudo /opt/CrowdStrike/falconctl -s --cid=$FALCON_CID

sudo /opt/CrowdStrike/falconctl -g --cid
```

6. **Start the sensor**
```
service falcon-sensor start
systemctl start falcon-sensor
```

7. **Verify the sensor**
* **`Falcon Console`** → **`Host setup and management`** → **`Manage endpoints`** → **`Host management`**
  * Sort by the **`First seen`** column

## Exercise 2 - Verify and troubleshoot the sensor status

1. **Checking the sensor version and that it is running**
```
/opt/CrowdStrike/falconctl -g --version
systemctl status falcon-sensor
ps -e | grep falcon-sensor
```

2. **Verify the sensor CID configuration**
```
/opt/CrowdStrike/falconctl -g --cid
```

3. **Check logs for communication**
```
tail -f /var/log/falconctl.log

cat /var/log/falcon-sensor.log
cat /var/log/falconctl.log
cat /var/log/falcond.log
```
