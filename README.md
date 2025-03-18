# passSprayer



**Usage: .\passSprayer.ps1 -u <userList> -p <passWord> -d <domain> -dc <dc> [-t thread default 5] [-NoColor] [-h]**

-u (UserFile): Required, path to the user list file

-p (Password): Required, test password

-d (Domain): Required, target domain

-dc (DomainController): Required, domain controller address

-t (Threads): Optional, number of threads (default: 5)

-NoColor: Disable colored output

-h (Help): Display help information

Example:
.\passSprayer.ps1 -u users.txt -p 'P@ssw0rd!' -d domain -dc dc01 -t 10
![image](https://github.com/user-attachments/assets/63a82308-b0a8-4732-a608-8dde1e4e3dab)

![image](https://github.com/user-attachments/assets/5e5a1678-9915-4f4c-9b9c-b4e747e19f1a)

