# userObject
User Object for Run Basic

### Usage

### Methods

#### isnull()
Return 0.

#### debugs$()
Returns "User Object"

#### setDatabaseName(name$)
Sets the location of the user database to **name$**. Returns 1 on success or 0 failure.

### setSmtpProfile(host$, password$, from$)
Sets the SMTP host, password and from address used to send emails. Returns 1 on success or 0 failure.

### new(username$, password$)
Create a new user with the supplied username and password. Returns the userid of the new user on success or 0 failure.

### register(username$, email$)
Register a new user with then supplied username and email address. A random password will be generated and sent to the email address. Returns the userid of the new user on success or 0 failure.

### selectUserByName(username$)
Sets the current user to the user identified by **username$**. Returns the userid on success or 0 failure.

### selectUserById(id)
Sets the curent user to the user with a userid of **id**. Returns the userid on success or 0 failure.

### deleteuser()
Deletes the current user. Returns 1 on success or 0 on failure.

### listUsers(order$)
Prepare to list users sorted by **order$**. **order$** may be either "ID", "USERNAME" or "LASTLOGIN". Returns 1 on success or 0 on failure.

### nextUser()
Sets the current user to the next user as sorted by the order set using **listusers()**. Returns the userid on success or 0 on failure or when there are no more users to select.

### lostPassword()
Resets the current users password and emails it to their email address. Returns 1 on success or 0 on failure.

