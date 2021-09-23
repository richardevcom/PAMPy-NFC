import "components"

import QtQuick 2.0
import QtQuick.Layouts 1.2

import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents

SessionManagementScreen {

    property bool showUsernamePrompt: !showUserList

    property string lastUserName

    property string tempUsername
    property string tempPassword
    property string tempPin
    property string tempNFC

    //the y position that should be ensured visible when the on screen keyboard is visible
    property int visibleBoundary: mapFromItem(loginButton, 0, 0).y
    onHeightChanged: visibleBoundary = mapFromItem(loginButton, 0, 0).y + loginButton.height + units.smallSpacing

    signal loginRequest(string username, string password)

    onShowUsernamePromptChanged: {
        if (!showUsernamePrompt) {
            lastUserName = ""
        }
    }

    /*
    * Login has been requested with the following username and password
    * If username field is visible, it will be taken from that, otherwise from the "name" property of the currentIndex
    */
    function startLogin() {
        var username = showUsernamePrompt ? userNameInput.text : userList.selectedUser
        var password = passwordBox.text

        //this is partly because it looks nicer
        //but more importantly it works round a Qt bug that can trigger if the app is closed with a TextField focussed
        //DAVE REPORT THE FRICKING THING AND PUT A LINK
        loginButton.forceActiveFocus();
        loginRequest(username, password);
    }

    /**
     * Initialize login sequene
     * also do remote state checks vai API
     */
    function initLogin(uid) {
        // Headers and params are optional
        devLog.text += "--> SENDING initial REQUEST -->\n"
        makeRequest({
            "action":"check",
            "UID": String(uid)
        }, function(status, response) {
            devLog.text += "--<--<--<--<--<--<--<\n"
            devLog.text += response
            devLog.text += "\n--<--<--<--<--<--<--<\n"
            var djson = JSON.parse(response)

            if(djson["State"] !== undefined) {
                devLog.text += "<-- STATE RECEIVED: " + djson["State"] + "\n"

                if([6, 7, 17, 20].indexOf(djson["State"]) >= 0){
                    if(djson["State"] == 6) {
                        devLog.text += "=== ENTER PIN ===\n"

                        tempUsername    = djson["Username"]
                        tempPassword    = djson["Password"]
                        tempPin         = djson["Pin"]
                        tempNFC         = uid

                        userNameInput.text = tempUsername
                        passwordBox.text = tempPassword
                        pinUi()
                    }

                    if(djson["State"] == 7) {
                        devLog.text += "=== REGISTERING NFC ===\n"
                        root.notificationMessage = i18nd("plasma_lookandfeel_org.kde.lookandfeel","Registering...")


                        tempNFC         = uid
                        userNameInput.text = ""
                        passwordBox.text = ""

                        registerUi()
                    }

                    if(djson["State"] == 20) {
                        devLog.text += "!!! NFC BANNED !!!\n"
                        root.notificationMessage = i18nd("plasma_lookandfeel_org.kde.lookandfeel","NFC Card is banned!")

                        tempNFC         = uid
                        userNameInput.text = ""
                        passwordBox.text = ""

                        resetUi()
                        userNameInput.text = tempUsername
                    }
                }else{
                    startLogin()
                }
            }else{
                devLog.text += "!!! FATAL ERROR: no status received. " + response + "\n"
                startLogin()
            }
        })
    }

    /**
     * Make HTTP request to API
     */
    function makeRequest (sdata, callback) {
        var xhr = new XMLHttpRequest();

        xhr.open('POST', 'http://localhost:30080', true);
        xhr.setRequestHeader('Content-Type', 'application/json');

        xhr.onreadystatechange = function() {
            if(xhr.readyState === XMLHttpRequest.DONE) {
                var status = xhr.status;
                if (xhr.readyState == 4 && xhr.status == 200) {
                    callback(true, xhr.responseText);
                }
            }
        };

        xhr.onerror = function () {
          callback(false, xhr.responseText);
        };

        xhr.timeout = 10000; // @richardev - Set timeout to 10 seconds (10000 milliseconds)
        xhr.ontimeout = function () {
            callback(false, xhr.responseText);
        }

        xhr.send(JSON.stringify(sdata));
    }

    function authPin(){
        devLog.text += "--- Matching " + pinBox.text + " with " + tempPin + " ---\n"
        if(pinBox.text == tempPin){
            devLog.text += "PIN OK! :)\n"
            root.notificationMessage = i18nd("plasma_lookandfeel_org.kde.lookandfeel","PIN Ok. Logging in!")
            makeRequest({
                "action":"auth",
                "UID": String(tempNFC)
            })
            startLogin()
        }else{
            root.notificationMessage = i18nd("plasma_lookandfeel_org.kde.lookandfeel","Invalid PIN code. Try again!")
            devLog.text += "PIN NOT OK! :(\n"
            pinBox.text = ""
        }
    }

    function authRegister(){
        devLog.text += "--- Registering " + tempNFC + "---\n"
        tempUsername = userNameInputRegister.text
        tempPassword = passwordBoxRegister.text
        tempPin = pinBoxRegister.text

        makeRequest({
            "action":"register",
            "UID": String(tempNFC),
            "Username": userNameInputRegister.text,
            "Password": passwordBoxRegister.text,
            "Pin": pinBoxRegister.text
        }, function(status, response){
            devLog.text += response + "\n"
            var djson = JSON.parse(response)

            if(djson["State"] !== undefined) {
                devLog.text += "<-- STATE RECEIVED: " + djson["State"] + "\n"

                if(djson["State"] == 3){
                    root.notificationMessage = i18nd("plasma_lookandfeel_org.kde.lookandfeel","Registered! Logging in.")
                    devLog.text += ":) REGISTERED. LOGGING IN!" + tempNFC + "\n"
                    userNameInput.text = tempUsername
                    tempPassword.text = tempPassword
                    pinBox.text = tempPin
                    makeRequest({
                        "action":"auth",
                        "UID": String(tempNFC)
                    })
                    startLogin()
                }else{
                    root.notificationMessage = i18nd("plasma_lookandfeel_org.kde.lookandfeel","Couldn't register! Try again.")
                    devLog.text += "--- ERROR REGISTERING ---\n"
                }
            }else{
                root.notificationMessage = i18nd("plasma_lookandfeel_org.kde.lookandfeel","Couldn't register! Try again.")
                devLog.text += "--- ERROR REGISTERING ---\n"
            }    
        })
    }

    // Main grid
    GridLayout {
        id: inputRow
        anchors.fill: parent
        rows: 4
        columns: 2

        ////////// AUTH ///////////////
        // Username Input
        PlasmaComponents.TextField {
            id: userNameInput
            Layout.fillWidth: true

            Layout.rowSpan   : 1
            Layout.columnSpan: 2

            text: lastUserName
            visible: showUsernamePrompt
            focus: showUsernamePrompt && !lastUserName //if there's a username prompt it gets focus first, otherwise password does
            placeholderText: i18nd("plasma_lookandfeel_org.kde.lookandfeel", "Username")

            onAccepted: passwordBox.forceActiveFocus()
        }

        // Password Input
        PlasmaComponents.TextField {
            id: passwordBox
            Layout.fillWidth: true

            Layout.rowSpan   : 2
            Layout.columnSpan: 2

            placeholderText: i18nd("plasma_lookandfeel_org.kde.lookandfeel", "Password")
            focus: !showUsernamePrompt || lastUserName
            echoMode: TextInput.Password
            revealPasswordButtonShown: true

            // onAccepted: startLogin()
            onAccepted: initLogin(passwordBox.text)
            
            Keys.onEscapePressed: {
                mainStack.currentItem.forceActiveFocus();
            }

            //if empty and left or right is pressed change selection in user switch
            //this cannot be in keys.onLeftPressed as then it doesn't reach the password box
            Keys.onPressed: {
                if (event.key == Qt.Key_Left && !text) {
                    userList.decrementCurrentIndex();
                    event.accepted = true
                }
                if (event.key == Qt.Key_Right && !text) {
                    userList.incrementCurrentIndex();
                    event.accepted = true
                }
            }

            Connections {
                target: sddm
                onLoginFailed: {
                    passwordBox.selectAll()
                    passwordBox.forceActiveFocus()
                }
            }
        }

        // Pin Input
        PlasmaComponents.TextField {
            id: pinBox
            Layout.fillWidth: true

            Layout.rowSpan   : 1
            Layout.columnSpan: 2

            visible: false

            placeholderText: i18nd("plasma_lookandfeel_org.kde.lookandfeel", "PIN")
            echoMode: TextInput.Password
            revealPasswordButtonShown: true

            onAccepted: authPin()
        }


        ////////// REGISTER ///////////
        // Username Input
        PlasmaComponents.TextField {
            id: userNameInputRegister
            Layout.fillWidth: true

            Layout.rowSpan   : 1
            Layout.columnSpan: 2

            text: ""
            visible: false
            placeholderText: i18nd("plasma_lookandfeel_org.kde.lookandfeel", "Username")

            onAccepted: authRegister()
        }

        // Password Input
        PlasmaComponents.TextField {
            id: passwordBoxRegister
            Layout.fillWidth: true

            Layout.rowSpan   : 2
            Layout.columnSpan: 2

            echoMode: TextInput.Password
            revealPasswordButtonShown: true
            text: ""
            visible: false
            placeholderText: i18nd("plasma_lookandfeel_org.kde.lookandfeel", "Password")

            onAccepted: authRegister()
        }

        // Pin Input
        PlasmaComponents.TextField {
            id: pinBoxRegister
            Layout.fillWidth: true

            Layout.rowSpan   : 3
            Layout.columnSpan: 2

            echoMode: TextInput.Password
            revealPasswordButtonShown: true
            text: ""
            visible: false
            placeholderText: i18nd("plasma_lookandfeel_org.kde.lookandfeel", "PIN")

            onAccepted: authRegister()
        }

        // Login Button
        PlasmaComponents.Button {
            id: loginButton
            Layout.fillWidth: true
            Layout.rowSpan   : 3
            Layout.columnSpan: 2

            text: i18nd("plasma_lookandfeel_org.kde.lookandfeel", "Login")
            onClicked: initLogin();
        }

        // Auth Button
        PlasmaComponents.Button {
            id: authButton

            Layout.rowSpan   : 3
            Layout.columnSpan: 1

            visible: false

            text: i18nd("plasma_lookandfeel_org.kde.lookandfeel", "Authorize")
            onClicked: authPin();
        }

        // Register Button
        PlasmaComponents.Button {
            id: registerButton

            Layout.rowSpan   : 4
            Layout.columnSpan: 1

            visible: false

            text: i18nd("plasma_lookandfeel_org.kde.lookandfeel", "Register")
            onClicked: authRegister();
        }

        // Back
        PlasmaComponents.Button {
            id: backButton

            Layout.rowSpan   : 3
            Layout.columnSpan: 1

            visible: false

            text: i18nd("plasma_lookandfeel_org.kde.lookandfeel", "Back")
            onClicked: resetUi();
        }
    }



    /**
     * Reset UI visual state back to initial
     */
    function resetUi() {
        userNameInput.visible = showUsernamePrompt
        passwordBox.visible = true
        pinBox.visible = false
        userNameInputRegister.visible = false
        passwordBoxRegister.visible = false
        pinBoxRegister.visible = false
        
        backButton.visible = false
        loginButton.visible = true
        authButton.visible = false
        registerButton.visible = false

        backButton.Layout.rowSpan = 3

        userNameInput.text = tempUsername
        passwordBox.text = ""
        pinBox.text = ""

        passwordBox.forceActiveFocus()

        root.notificationMessage = ""
    }


    /**
     * Set PIN UI visual state
     */
    function pinUi() {
        userNameInput.visible = false
        passwordBox.visible = false
        pinBox.visible = true

        loginButton.visible = false
        authButton.visible = true
        backButton.visible = true

        userNameInput.text = tempUsername

        pinBox.forceActiveFocus()

        root.notificationMessage = i18nd("plasma_lookandfeel_org.kde.lookandfeel","Please enter PIN code.")
    }

    /**
     * Set REGISTER UI visual state
     */
    function registerUi() {
        userNameInput.visible = false
        passwordBox.visible = false

        userNameInputRegister.visible = true
        passwordBoxRegister.visible = true
        pinBoxRegister.visible = true

        loginButton.visible = false
        registerButton.visible = true
        backButton.visible = true

        backButton.Layout.rowSpan = 4

        userNameInput.text = ""

        userNameInputRegister.forceActiveFocus()

        root.notificationMessage = i18nd("plasma_lookandfeel_org.kde.lookandfeel","Please enter user credentials.")
    }
}
