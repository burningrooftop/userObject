' userObject
' by Neal Collins, 2009 - 2015
'
' This code is public domain.

global #lib
run "functionLibrary", #lib

'
' Location of the default user database
'
UserDatabase$ = "projects" + #lib pathSeparator$() + "userObject_project" + #lib pathSeparator$() + "users.db"

global #db, UserDatabase$, ErrorMessage$, Result, SmtpHost$, SmtpPassword$, FromAddress$, Order$
global ApplicationName$
global Id, Username$, Email$, Description$, Salt$, Password$, LastLoginDate, LastLoginTime, Locked

call createTables

'--------------------------------------------
' isnull
' -------------------------------------------
function isnull()
  isnull = 0
end function

' -------------------------------------------
' debug$
' -------------------------------------------
function debug$()
  debug$ = "User Object"
end function

' -------------------------------------------
' setDatabaseName
' -------------------------------------------
function setDatabaseName(databaseName$)
  if databaseName$ = "" then
    ErrorMessage$ = "Database Name must not be empty."
    goto [endFunction]
  end if

  UserDatabase$ = databaseName$

  call createTables

  setDatabaseName = 1
[endFunction]
end function

' -------------------------------------------
' setSmptProfile
' -------------------------------------------
function setSmtpProfile(host$, password$, from$)
  if host$ = "" then
    ErrorMessage$ = "Hostname must not be empty."
    goto [endFunction]
  end if

  if from$ = "" then
    ErrorMessage$ = "From Email Address must not be empty."
    goto [endFunction]
  end if

  SmtpHost$ = host$
  SmtpPassword$ = password$
  FromAddress$ = from$

  setSmtpProfile = 1

[endFunction]
end function

' -------------------------------------------
' new
' -------------------------------------------
function new(username$, password$)
  call clearUser

  if username$ = "" then
    ErrorMessage$ = "Username must not be empty."
    goto [endFunction]
  end if

  if duplicate(username$) then
    ErrorMessage$ = "Username """ + username$ + """ has already been used."
    goto [endFunction]
  end if

  Salt$ = salt$()
  call execute "INSERT INTO user (username, salt, password, creation_date, creation_time, last_update_date, last_update_time) VALUES (" + #lib quote$(username$) + "," + #lib quote$(Salt$) + "," + #lib quote$(encrypt$(Salt$, password$)) + "," + str$(date$("days")) + "," + str$(myTime()) + "," + str$(date$("days")) + "," + str$(myTime()) + ")"

  call loadUser username$, 0
  new = Id

  [endFunction]
end function

' -------------------------------------------
' register
' -------------------------------------------
function register(username$, email$)
  call clearUser

  if email$ = "" then
    ErrorMessage$ = "An email address is required."
    goto [endFunction]
  end if

  password$ = randomPassword$()

  register = new(username$, password$)

  if register = 0 then goto [endFunction]
  if setEmail(email$) = 0 then goto [endFunction]

  call sendEmail Email$, "Registration successful", "Your registration has been successful. Your username is """ + username$ + """ and your password is """ + password$ + """."

  call clearUser

[endFunction]
end function

' -------------------------------------------
' selectUserByName
' -------------------------------------------
function selectUserByName(username$)
  if username$ = "" then
    ErrorMessage$ = "Username or email address must be supplied."
    goto [endFunction]
  end if

  call loadUser username$, 0

  if Id = 0 then
    ErrorMessage$ = "Invalid username or email address."
    goto [endFunction]
  end if

  selectUserByName = Id

[endFunction]
end function

' -------------------------------------------
' selectUserById
' -------------------------------------------
function selectUserById(id)

  call loadUser "", id

  if Id = 0 then
    ErrorMessage$ = "Invalid username or email address."
    goto [endFunction]
  end if

  selectUserById = Id

[endFunction]
end function

' -------------------------------------------
' deleteUser
' -------------------------------------------
function deleteUser()
  if Id <> 0 then
    call execute "delete from applications where user_id = " + str$(Id)
    call execute "delete from user where id = " + str$(Id)
    call clearUser
    deleteUser = 1
  end if
end function

' -------------------------------------------
' listUsers
' -------------------------------------------
function listUsers(order$)
  Order$ = upper$(order$)
  if Order$ = "ID" or Order$ = "USERNAME" or Order$ = "LASTLOGIN" then
    call clearUser
    listUsers = 1
  else
    Order$ = ""
    ErrorMessage$ = "Invalid order parameter."
  end if
end function

' -------------------------------------------
' nextUser
' -------------------------------------------
function nextUser()
  query$ = "SELECT id FROM user "
  select case Order$
    case "ID"
      query$ = query$ + "WHERE id > " + str$(Id) + " ORDER BY id"
    case "USERNAME" 
      query$ = query$ + "WHERE UPPER(username) > UPPER(" + #lib quote$(Username$) + ") ORDER BY UPPER(username)"
    case "LASTLOGIN"
      query$ = query$ + "WHERE (last_login_date = " + str$(LastLoginDate) + " AND last_login_time > " + str$(LastLoginTime) + ") OR last_login_date > " + str$(LastLoginDate) + " ORDER BY last_login_date, last_login_time"
  end select

  call connect
  #db execute(query$)
  if #db hasanswer() then
    #row = #db #nextrow()
    id = #row id()
    call disconnect
    nextUser = selectUserById(id)
  else
    call disconnect
  end if
end function

' -------------------------------------------
' lostPassword
' -------------------------------------------
function lostPassword(username$)
  if username$ = "" then
    ErrorMessage$ = "Username or email address must be supplied."
    goto [endFunction]
  end if

  call loadUser username$, 0

  if Id = 0 then
    ErrorMessage$ = "No matching username or email address found."
    goto [endFunction]
  end if
  
  password$ = randomPassword$()
  if setPassword(password$) = 0 then goto [endFunction]

  call sendEmail Email$, "Password Reset Successful" "Your password reset has been successful. Yor new password is """ + password$ + """."

  call clearUser

  lostPassword = 1

[endFunction]
end function

' -------------------------------------------
' login
' -------------------------------------------
function login(username$, password$)
  if username$ = "" then
    ErrorMessage$ = "Username or email address must be supplied."
    goto [endFunction]
  end if

  call loadUser username$, 0

  if Id = 0 then
    ErrorMessage$ = "Invalid username or password."
    goto [endFunction]
  end if

  if encrypt$(Salt$, password$) <> Password$ then
    ErrorMessage$ = "Invalid username or password."
    call clearUser
    goto [endFunction]
  end if

  if Locked then
    ErrorMessage$ = "Account is locked."
    call clearUser
    goto [endFunction]
  end if

  if ApplicationName$ <> "" then
    if not(checkApplication(ApplicationName$)) then
      ErrorMessage$ = "Application access denied."
      call clearUser
      goto [endFunction]
    end if
  end if

  call execute "UPDATE user SET last_login_date = " + str$(date$("days")) + ", last_login_time = " + str$(myTime()) + " WHERE id = " + str$(Id)

  login = Id

[endFunction]
end function

' -------------------------------------------
' logout
' -------------------------------------------
function logout()
  call clearUser
end function

' -------------------------------------------
' authenticate
' -------------------------------------------
function authenticate(token$)
  if token$ = "" then
    ErrorMessage$ = "Token must be supplied."
    goto [endFunction]
  end if

  call clearUser

  call connect
  #db execute("SELECT user_id AS id FROM token WHERE token = " + #lib quote$(token$))
  if #db hasanswer() then
    #row = #db #nextrow()
    id = #row id()
    #db execute("DELETE FROM token WHERE token = " + #lib quote$(token$))
  end if
  call disconnect

  if id = 0 then
    ErrorMessage$ = "Invalid token."
    goto [endFunction]
  end if

  call loadUser "", id

  if Id = 0 then
    ErrorMessage$ = "Invalid user specified by token."
    goto [endFunction]
  end if

  if Locked then
    ErrorMessage$ = "Account is locked."
    call clearUser
    goto [endFunction]
  end if

  call execute "UPDATE user SET last_login_date = " + str$(date$("days")) + ", last_login_time = " + str$(myTime()) + " WHERE id = " + str$(Id)

  authenticate = Id

[endFunction]
end function

' -------------------------------------------
' addApplication
' -------------------------------------------
function addApplication(app$)
  if app$ = "" then
    ErrorMessage$ = "Application name must be supplied."
    goto [endFunction]
  end if
  if not(checkApplication(app$)) then
    call execute "INSERT INTO applications (user_id, project) VALUES (" + str$(Id) + "," + #lib quote$(app$) + ")"
  end if
  addApplication = 1
[endFunction]
end function

' -------------------------------------------
' deleteApplication
' -------------------------------------------
function deleteApplication(app$)
  call execute "DELETE FROM applications WHERE project = " + #lib quote$(app$) + " AND user_id = " + str$(Id)
  deleteApplication = 1
end function

' -------------------------------------------
' checkApplication
' -------------------------------------------
function checkApplication(app$)
  call connect
  #db execute("SELECT 1 FROM applications WHERE project = " + #lib quote$(app$) + " AND user_id = " + str$(Id))
  if #db hasanswer() then checkApplication = 1
  call disconnect
end function

' -------------------------------------------
' changePassword
' -------------------------------------------
function changePassword(oldPassword$, newPassword$, verify$)
  if Id = 0 then
    ErrorMessage$ = "Not logged in."
    goto [endFunction]
  end if

  if encrypt$(Salt$, oldPassword$) <> Password$ then
    ErrorMessage$ = "Incorrect old password."
    goto [endFunction]
  end if

  if newPassword$ <> verify$ then
    ErrorMessage$ = "New passwords do not match."
    goto [endFunction]
  end if

  changePassword = setPassword(newPassword$)

[endFunction]
end function

' -------------------------------------------
' loginPage
' -------------------------------------------
function loginPage(app$, title$, #appSession)
  run "session", #authSession
  #authSession new()
  #authSession set("app", app$)
  #authSession set("title", title$)
  if not(#appSession isnull()) then
    #authSession set("session", str$(#appSession id()))
  end if
  #authSession runProject("loginManager")
end function

' -------------------------------------------
' profilePage
' -------------------------------------------
function profilePage(app$, title$, #appSession)
  t$ = token$()
  run "session", #authSession
  #authSession new()
  #authSession set("token", t$)
  #authSession set("app", app$)
  #authSession set("title", title$)
  if not(#appSession isnull()) then
    #authSession set("session", str$(#appSession id()))
  end if
  #authSession runProject("loginManager")
end function

' -------------------------------------------
' runProject
' -------------------------------------------
function runProject(app$, #appSession)
  t$ = token$()
  run "session", #authSession
  #authSession new()
  #authSession set("token", t$)
  if not(#appSession isnull()) then
    #authSession set("session", str$(#appSession id()))'
  end if
  #authSession runProject(app$)
end function

' -------------------------------------------
' authenticateSession
' -------------------------------------------
function authenticateSession(urlkeys$, #appSession)
  sid = val(#lib getUrlParam$(urlkeys$, "session"))
  if sid > 0 then
    run "session", #authSession
    #authSession connect(sid)
    token$ = #authSession value$("token")
    sid = val(#authSession value$("session"))
    #authSession clear()
    authenticateSession = authenticate(token$)
    if sid > 0 and not(#appSession isnull()) then
      #appSession connect(sid)
    end if
  end if
end function

' Getter functions
' ===========================================

' -------------------------------------------
' getApplication$
' -------------------------------------------
function getApplication$()
  getApplication$ = ApplicationName$
end function

' -------------------------------------------
' getDatabaseName$
' -------------------------------------------
function getDatabaseName$()
  getDatabaseName$ = UserDatabase$
end function

' -------------------------------------------
' id
' -------------------------------------------
function id()
  id = Id
end function

' -------------------------------------------
' username$
' -------------------------------------------
function username$()
  username$ = Username$
end function

' -------------------------------------------
' description$
' -------------------------------------------
function description$()
  description$ = Description$
end function

' -------------------------------------------
' email$
' -------------------------------------------
function email$()
  email$ = Email$
end function

' -------------------------------------------
' lastLoginDate
' -------------------------------------------
function lastLoginDate()
  lastLoginDate = LastLoginDate
end function

' -------------------------------------------
' lastLoginTime
' -------------------------------------------
function lastLoginTime()
  lastLoginTime = lastLoginTime
end function

' -------------------------------------------
' errorMessage$
' -------------------------------------------
function errorMessage$()
  errorMessage$ = ErrorMessage$
  ErrorMessage$ = ""
end function

' -------------------------------------------
' locked
' -------------------------------------------
function locked()
  locked = Locked
end function

' -------------------------------------------
' token$
' -------------------------------------------
function token$()
  if Id = 0 then
    ErrorMessage$ = "Not logged in."
    goto [endFunction]
  end if

  token$ = randomToken$()

  call connect
  #db execute("INSERT INTO token (token, user_id, creation_date, creation_time) VALUES (" + #lib quote$(token$) + "," + str$(Id) + "," + str$(date$("days")) + "," + str$(myTime()) + ")")
  call disconnect
  [endFunction]
end function

' -------------------------------------------
' getAppURL$
' -------------------------------------------
function getAppURL$(app$)
  t$ = token$()
  if t$ <> "" then getAppURL$ = "/seaside/go/runbasicpersonal?app=" + #lib urlEncode$(app$) + "&token=" + t$
end  function

' -------------------------------------------
' getLoginURL$
' -------------------------------------------
function getLoginURL$(url$, title$)
  url$ = fixURL$(url$)
  getLoginURL$ = "/seaside/go/runbasicpersonal?app=auth&title=" + #lib urlEncode$(title$) + "&url=" + #lib urlEncode$(url$)
end  function

' -------------------------------------------
' getProfileURL$
' -------------------------------------------
function getProfileURL$(url$, title$)
  url$ = fixURL$(url$)
  t$ = token$()
  if t$ <> "" then getProfileURL$ = "/seaside/go/runbasicpersonal?app=auth&title=" + #lib urlEncode$(title$) + "&url=" + #lib urlEncode$(url$) + "&token=" + t$
end  function

' Setter functions
' ===========================================

' -------------------------------------------
' setApplication
' -------------------------------------------
function setApplication(app$)
  ApplicationName$ = app$
  setApplication = 1
end function

' -------------------------------------------
' setUsername
' -------------------------------------------
function setUsername(username$)
  if Username$ = username$ then
    setUsername = 1
  else
    if duplicate(username$) then
      ErrorMessage$ = "Username """ + username$ + """ has already been used."
      setUsername = 0
    else
      Username$ = username$
      call updateUser "username", username$
      setUsername = Result
    end if
  end if
end function

' -------------------------------------------
' setDescription
' -------------------------------------------
function setDescription(description$)
  if Description$ = description$ then
    setDescription = 1
  else
    Description$ = description$
    call updateUser "description", description$
    setDescription = Result
  end if
end function

' -------------------------------------------
' setEmail
' -------------------------------------------
function setEmail(email$)
  if Email$ = email$ then
    setEmail = 1
  else
    if duplicate(email$) then
      ErrorMessage$ = "Email """ + email$ + """ has already been used."
      setEmail = 0
    else
      Email$ = email$
      call updateUser "email", email$
      setEmail = Result
    end if
  end if
end function

' -------------------------------------------
' setPassword
' -------------------------------------------
function setPassword(password$)
  Password$ = password$
  call updateUser "password", encrypt$(Salt$, password$)
  setPassword = Result
end function

' -------------------------------------------
' lockUser
' -------------------------------------------
function lockUser()
  Locked = 1
  call updateUser "locked", "1"
  lockUser = Result
end function

' -------------------------------------------
' unlockUser
' -------------------------------------------
function unlockUser()
  Locked = 0
  call updateUser "locked", "0"
  unlockUser = Result
end function

' Private Functions
' ===========================================

' -------------------------------------------
' duplicate
' -------------------------------------------
function duplicate(value$)
  call connect
  #db execute("SELECT 'X' FROM user WHERE UPPER(username) = UPPER(" + #lib quote$(value$) + ") OR UPPER(email) = UPPER(" + #lib quote$(value$) + ")")
  duplicate = #db hasanswer()
  #db disconnect()
end function

' -------------------------------------------
' fixURL$
' -------------------------------------------
function fixURL$(url$)
  if left$(lower$(url$), 5) = "http:" or left$(lower$(url$), 6) = "https:" or left$(url$, 1) = "/" then
    fixURL$ = url$
  else
    fixURL$ = "/seaside/go/runbasicpersonal?app=" + url$
  end if
end function

' -------------------------------------------
' myWord$
' -------------------------------------------
function myWord$(string$, n, delimiter$)
  myWord$ = word$(string$, n, delimiter$)
  if myWord$ = delimiter$ then myWord$ = ""
end function

' -------------------------------------------
' myTime
' -------------------------------------------
function myTime()
  t$ = time$()
  myTime = val(word$(t$, 1, ":")) * 3600 + val(word$(t$, 2, ":")) * 60 + val(word$(t$, 3, ":"))
end function

' -------------------------------------------
' randomPassword$
' -------------------------------------------
function randomPassword$()
 randomPassword$ = ""
  for i = 1 to 6 + rnd(1) * 4
    randomPassword$ = randomPassword$ + mid$("abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789", 1 + int(rnd(1) * 58), 1)
  next i
end function

' -------------------------------------------
' randomToken$
' -------------------------------------------
function randomToken$()
 randomToken$ = ""
  for i = 1 to 24
    randomToken$ = randomToken$ + mid$("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789", 1 + int(rnd(1) * 35), 1)
  next i
end function

' -------------------------------------------
' salt$
' -------------------------------------------
function salt$()
  salt$ = ""
  for i = 1 to 16
    salt$ = salt$ + chr$(33 + int(rnd(1) * 93))
  next i
end function

' -------------------------------------------
' encrypt$
' -------------------------------------------
function encrypt$(salt$, password$)
  M$ = salt$ + password$

  N = len(M$)

  r = 16 - (N mod 16)
  if r = 0 then r = 16

  for i = 0 to r - 1
    M$ = M$ + chr$(r)
  next i

  N = N + r

  dim S(255)

  restore
  for i = 0 to 255
    read S(i)
  next i

  dim C(15)

  L = 0

  for i = 0 to N / 16 - 1
    for j = 0 to 15
      c = asc(mid$(M$, i * 16 + j + 1, 1))
      C(j) = C(j) xor S(c xor L)
      L = C(j)
    next j
  next i

  for i = 0 to 15
    M$ = M$ + chr$(C(i))
  next i

  N = N + 16

  dim X(47)

  for i = 0 to N / 16 - 1

    for j = 0 to 15
      X(16 + j) = asc(mid$(M$, i * 16 + j + 1, 1))
      X(32 + j) = X(16 + j) xor X(j)
    next j

    t = 0

    for j = 0 to 17

      for k = 0 to 47
        t = X(k) xor S(t)
        X(k) = t
      next k

      t = (t + j) mod 256
    next j
  next i

  X$ = ""

  for i = 0 to 15 
    X$ = X$ + right$("0" + dechex$(X(i)), 2)
  next i

  encrypt$ = X$

  data 41, 46, 67, 201, 162, 216, 124, 1, 61, 54, 84, 161, 236, 240, 6
  data 19, 98, 167, 5, 243, 192, 199, 115, 140, 152, 147, 43, 217, 188
  data 76, 130, 202, 30, 155, 87, 60, 253, 212, 224, 22, 103, 66, 111, 24
  data 138, 23, 229, 18, 190, 78, 196, 214, 218, 158, 222, 73, 160, 251
  data 245, 142, 187, 47, 238, 122, 169, 104, 121, 145, 21, 178, 7, 63
  data 148, 194, 16, 137, 11, 34, 95, 33, 128, 127, 93, 154, 90, 144, 50
  data 39, 53, 62, 204, 231, 191, 247, 151, 3, 255, 25, 48, 179, 72, 165
  data 181, 209, 215, 94, 146, 42, 172, 86, 170, 198, 79, 184, 56, 210
  data 150, 164, 125, 182, 118, 252, 107, 226, 156, 116, 4, 241, 69, 157
  data 112, 89, 100, 113, 135, 32, 134, 91, 207, 101, 230, 45, 168, 2, 27
  data 96, 37, 173, 174, 176, 185, 246, 28, 70, 97, 105, 52, 64, 126, 15
  data 85, 71, 163, 35, 221, 81, 175, 58, 195, 92, 249, 206, 186, 197
  data 234, 38, 44, 83, 13, 110, 133, 40, 132, 9, 211, 223, 205, 244, 65
  data 129, 77, 82, 106, 220, 55, 200, 108, 193, 171, 250, 36, 225, 123
  data 8, 12, 189, 177, 74, 120, 136, 149, 139, 227, 99, 232, 109, 233
  data 203, 213, 254, 59, 0, 29, 57, 242, 239, 183, 14, 102, 88, 208, 228
  data 166, 119, 114, 248, 235, 117, 75, 10, 49, 68, 80, 180, 143, 237
  data 31, 26, 219, 153, 141, 51, 159, 17, 131, 20
end function

' -------------------------------------------
' clearUser
' -------------------------------------------
sub clearUser
  Id = 0
  Username$ = ""
  Email$ = ""
  Description$ = ""
  Salt$ = ""
  Password$ = ""
  LastLoginDate = 0
  LastLoginTime = 0
  Locked = 0
  AppData$ = ""
end sub

' -------------------------------------------
' createTables
' -------------------------------------------
sub createTables
  call execute "CREATE TABLE IF NOT EXISTS user (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,username TEXT NOT NULL UNIQUE,description TEXT,email TEXT UNIQUE,salt TEXT NOT NULL,password TEXT NOT NULL,creation_date INTEGER NOT NULL,creation_time INTEGER NOT NULL,last_update_date INTEGER NOT NULL,last_update_time INTEGER NOT NULL,locked INTEGER NOT NULL DEFAULT '0',last_login_date INTEGER NOT NULL DEFAULT '0',last_login_time INTEGER NOT NULL DEFAULT '0')"

  call execute "CREATE TABLE IF NOT EXISTS token (token TEXT NOT NULL UNIQUE,user_id INTEGER NOT NULL,creation_date INTEGER NOT NULL,creation_time INTEGER NOT NULL)"

  call execute "CREATE TABLE IF NOT EXISTS applications (user_id INTEGER NOT NULL,project TEXT NOT NULL)"
end sub

' -------------------------------------------
' loadUser
' -------------------------------------------
sub loadUser username$, id

  call clearUser

  query$ = "SELECT id, username, email, salt, password, description, last_login_date lastlogindate, last_login_time lastlogintime, locked FROM user WHERE "
  if id <> 0 then
    query$ = query$ + "id = " + str$(id)
  else
    query$ = query$ + "UPPER(username) = UPPER(" + #lib quote$(username$) + ") OR UPPER(email) = UPPER(" + #lib quote$(username$) + ")"
  end if
  call connect
  #db execute(query$)
  if #db hasanswer() then
    #row = #db #nextrow()
    Id = #row id()
    Username$ = #row username$()
    Email$ = #row email$()
    Salt$ = #row salt$()
    Password$ = #row password$()
    Description$ = #row description$()
    LastLoginDate = #row lastlogindate()
    LastLoginTime = #row lastlogintime()
    Locked = #row locked()
  end if
  call disconnect
end sub

' -------------------------------------------
' updateUser
' -------------------------------------------
sub updateUser column$, value$
  if Id = 0 then
    ErrorMessage$ = "Not logged in."
    Result = 0
  else
    call execute "UPDATE user SET " + column$ + " = " + #lib quote$(value$) + ", last_update_date = " + str$(date$("days")) + ", last_update_time = " + str$(myTime()) + " WHERE ID = " + str$(Id)
    Result = 1
  end if
end sub

' -------------------------------------------
' connect
' -------------------------------------------
sub connect
  sqliteconnect #db, UserDatabase$
end sub

' -------------------------------------------
' disconnect
' -------------------------------------------
sub disconnect
  #db disconnect()
end sub

' -------------------------------------------
' execute
' -------------------------------------------
sub execute sql$
  call connect
  #db execute(sql$)
  call disconnect
end sub

' -------------------------------------------
' sendEmail
' -------------------------------------------
sub sendEmail email$, subject$, message$
  smtpsender #smtp, SmtpHost$
  #smtp password(SmtpPassword$)
  #smtp send(FromAddress$, email$, subject$, message$)
end sub
