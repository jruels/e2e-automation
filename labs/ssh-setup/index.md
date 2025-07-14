# Lab Setup 
To connect to the lab VMs, you must authenticate using an SSH key. Download the keys from [here](https://github.com/jruels/tf-dev/raw/refs/heads/main/keys.zip). Once the download is complete, extract the zip file where it is easily accessible.

### Mac/Linux

The username for SSH is 
`ec2-user`

Open a terminal and `cd` to the extracted lab directory that contains the SSH keys. Inside the directory, run the following command.

### Set permission on SSH keys

```
chmod 600 tower 
```



### SSH to lab servers

* Tower: 

```
ssh -i tower ec2-user@<TOWER IP FROM SPREADSHEET> 
```

* Managed nodes: 

```
ssh -i tower ec2-user@<MANAGED NODE IP FROM SPREADSHEET> 
```

### Set up Putty

If you don’t already have it, download Putty from [here](https://the.earth.li/~sgtatham/putty/latest/w64/putty.exe) and save it to your desktop.

Open Putty and configure new sessions for the Tower and Managed nodes.

![img](https://jruels.github.io/openshift-admin/labs/openshift-deploy/images/putty-session.png)

Expand Connection -> SSH -> Auth -> Credentials, click “Browse”, and then in the extracted `keys` directory, choose `tower.ppk` 

![image-20230918185300995](https://jruels.github.io/openshift-admin/labs/openshift-deploy/images/putty-auth.png)

**Remember to save your sessions**.
