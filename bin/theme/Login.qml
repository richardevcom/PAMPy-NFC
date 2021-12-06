import "components"

import QtQuick 2.0
import QtQuick.Layouts 1.2

import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents

SessionManagementScreen {
    property bool showUsernamePrompt: !showUserList
    property string lastUserName

    // @richardev - Where is onAccepted initially called from: username or password input?
    property string calledFrom: 'username'

    // Temporary auth credentials
    property variant temp: {
        "username":"",
        "password":"",
        "pin":""
    }

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
        makeRequest({
            "action":"check",
            "UID": String(uid)
        }, function(status, response) {
            var djson = JSON.parse(response)

            if(typeof djson === 'object' && djson["State"] !== undefined) {
                // debug
                debug.log("info", "Received State <b>" + djson["State"] + "</b>")

                // Received any valid state?
                if([6, 7, 17, 20].indexOf(djson["State"]) >= 0){

                    /** CARD FOUND - ASK PIN **/
                    if(djson["State"] == 6) {
                        debug.log("info", "NFC found. Authorizing...")

                        temp["username"]    = djson["Username"]
                        temp["password"]    = djson["Password"]

                        temp["pin"]         = djson["Pin"]
                        temp["nfc"]         = uid


                        userNameInput.text = temp["username"]
                        passwordBox.text = temp["password"]
                        pinUi()
                    }

                    /** CARD NOT FOUND - REGISTER **/
                    if(djson["State"] == 7) {
                        debug.log("info", "NFC not found. Registering...")

                        temp["nfc"]         = uid
                        userNameInput.text = ""
                        passwordBox.text = ""

                        registerUi()
                    }

                    /** CARD PASSWORD EXPIRED - CHANGE PASSWORD **/
                    if(djson["State"] == 17) {
                        debug.log("info", "Password expired. Change password!")

                        temp["nfc"]         = uid
                        temp["username"]    = djson["Username"]
                        userNameInput.text = ""
                        passwordBox.text = ""

                        changePasswordUi()
                    }

                    /** CARD BANNED **/
                    if(djson["State"] == 20) {
                        root.notificationMessage = i18nd("plasma_lookandfeel_org.kde.lookandfeel","NFC karte ir bloķēta!")

                        temp["nfc"]         = uid
                        userNameInput.text = ""
                        passwordBox.text = ""

                        resetUi()
                        userNameInput.text = temp["username"]
                    }
                }else if([0, -1, -3, -4].indexOf(djson["State"]) >= 0){
                    //debug
                    debug.log("error","Connection error: <b>State " + djson["State"] + "</b>")
                    
                    passwordBox.forceActiveFocus()
                    root.notificationMessage = i18nd("plasma_lookandfeel_org.kde.lookandfeel","Kļūda savienojumā ar Codelex API serveri!")
                }else{
                    if(calledFrom == 'username'){
                        if(userNameInput.text.length == 0) {
                            userNameInput.forceActiveFocus()
                            root.notificationMessage = i18nd("plasma_lookandfeel_org.kde.lookandfeel","Lūdzu norādiet lietotājvārdu!")
                        }else{
                            passwordBox.selectAll()
                            passwordBox.forceActiveFocus()
                        }
                    }else{
                        if(userNameInput.text.length == 0) {
                            userNameInput.forceActiveFocus()
                            root.notificationMessage = i18nd("plasma_lookandfeel_org.kde.lookandfeel","Lūdzu norādiet lietotājvārdu!")
                        }else if(passwordBox.text.length == 0){
                            passwordBox.forceActiveFocus()
                            root.notificationMessage = i18nd("plasma_lookandfeel_org.kde.lookandfeel","Lūdzu norādiet paroli!")
                        }else{
                            root.notificationMessage = i18nd("plasma_lookandfeel_org.kde.lookandfeel","Pieslēdzas...")
                            startLogin()
                        }
                    }
                }
            }else{
                root.notificationMessage = i18nd("plasma_lookandfeel_org.kde.lookandfeel","Nezināma kļūda! Mēģiniet vēlreiz.")
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
                    callback(true, xhr.responseText); // Another callback here
                }else{
                    callback(false, JSON.stringify({
                        "State": -5
                    }))
                }
            }
        };

        xhr.onerror = function () {
            callback(false, JSON.stringify({
                "State": -6
            }));
        };

        xhr.timeout = 10000; // @richardev - Set timeout to 10 seconds (10000 milliseconds)
        xhr.ontimeout = function () {
            callback(false, JSON.stringify({
                "State": -7
            }));
        }

        xhr.send(JSON.stringify(sdata));
    }

    /**
     * Authorize PIN code
     */
    function authPin(){
        if(pinBox.text == '') {
            root.notificationMessage = i18nd("plasma_lookandfeel_org.kde.lookandfeel","Lūdzu norādiet PIN kodu.")
            pinBox.forceActiveFocus()
            return false
        }

        if(pinBox.text == temp["pin"]){
            root.notificationMessage = i18nd("plasma_lookandfeel_org.kde.lookandfeel","PIN kods pareizs. Autorizē...")
            makeRequest({
                "action":"auth",
                "UID": String(temp["nfc"])
            }, function(){
                startLogin()    
            })
            
        }else{
            root.notificationMessage = i18nd("plasma_lookandfeel_org.kde.lookandfeel","Nepareizs PIN kods. Mēģiniet vēlreiz!")
            pinBox.text = ""
        }
    }

    /**
     * Authorize registration
     */
    function authRegister(){
        temp["username"] = userNameInputRegister.text
        temp["password"] = passwordBoxRegister.text
        temp["pin"] = pinBoxRegister.text

        root.clearNotification = false
        root.notificationMessage = i18nd("plasma_lookandfeel_org.kde.lookandfeel","Reģistrē... Uzgaidiet!")

        if(userNameInputRegister.text == '') {
            root.notificationMessage = i18nd("plasma_lookandfeel_org.kde.lookandfeel","Lūdzu norādiet lietotājvārdu.")
            userNameInputRegister.forceActiveFocus()
            return false
        }

        if(passwordBoxRegister.text == '') {
            root.notificationMessage = i18nd("plasma_lookandfeel_org.kde.lookandfeel","Lūdzu norādiet paroli.")
            passwordBoxRegister.forceActiveFocus()
            return false
        }

        if(pinBoxRegister.text == '') {
            root.notificationMessage = i18nd("plasma_lookandfeel_org.kde.lookandfeel","Lūdzu norādiet PIN kodu.")
            pinBoxRegister.forceActiveFocus()
            return false
        }

        makeRequest({
            "action":"register",
            "UID": String(temp["nfc"]),
            "Username": userNameInputRegister.text,
            "Password": passwordBoxRegister.text,
            "Pin": pinBoxRegister.text
        }, function(status, response){
            var djson = JSON.parse(response)

            if(djson["State"] !== undefined) {

                if(djson["State"] == 3){
                    resetUi()
                    root.notificationMessage = i18nd("plasma_lookandfeel_org.kde.lookandfeel","Reģistrācija veiksmīga!")
                    userNameInput.text = temp["username"]
                }else{
                    userNameInputRegister.forceActiveFocus()
                    root.notificationMessage = i18nd("plasma_lookandfeel_org.kde.lookandfeel","Nevarēja reģistrēt! Mēģiniet vēlreiz.")
                }
            }else{
                userNameInputRegister.forceActiveFocus()
                root.notificationMessage = i18nd("plasma_lookandfeel_org.kde.lookandfeel","Nevarēja reģistrēt! Mēģiniet vēlreiz.")
            }    
        })
    }

    /**
     * Authorize password change
     */
    function authChangePassword(old_password, final_password){
        root.clearNotification = false
        root.notificationMessage = i18nd("plasma_lookandfeel_org.kde.lookandfeel","Atjaunina paroli... Uzgaidiet!")

        if(old_password == final_password) {
            root.notificationMessage = i18nd("plasma_lookandfeel_org.kde.lookandfeel","Paroles nevar būt vienādas.")
            passwordBoxChange1.forceActiveFocus()
            return false
        }

        if(old_password == '') {
            root.notificationMessage = i18nd("plasma_lookandfeel_org.kde.lookandfeel","Vecā parole nevar būt tukša.")
            passwordBoxChange1.forceActiveFocus()
            return false
        }

        if(final_password == '') {
            root.notificationMessage = i18nd("plasma_lookandfeel_org.kde.lookandfeel","Jaunā parole nevar būt tukša.")
            passwordBoxChange2.forceActiveFocus()
            return false
        }

        makeRequest({
            "action":"change_password",
            "UID": String(temp["nfc"]),
            "Username": temp["username"],
            "OldPassword":old_password,
            "Password": final_password
        }, function(status, response){
            var djson = JSON.parse(response)

            if(djson["State"] !== undefined) {
                if(djson["State"] == 3){
                    resetUi()

                    root.notificationMessage = i18nd("plasma_lookandfeel_org.kde.lookandfeel","Parole atjaunināta!")
                    userNameInput.text = temp["username"]
                }else{
                    passwordBoxChange1.forceActiveFocus()
                    root.notificationMessage = i18nd("plasma_lookandfeel_org.kde.lookandfeel","Nevarēja atjaunināt paroli! Mēģiniet vēlreiz.")
                }
            }else{
                passwordBoxChange1.forceActiveFocus()
                root.notificationMessage = i18nd("plasma_lookandfeel_org.kde.lookandfeel","Nevarēja atjaunināt paroli! Mēģiniet vēlreiz.")
            }    
        })
    }

    /**
     * Main grid
     */
    GridLayout {
        id: inputRow
        anchors.fill: parent
        rows: 4
        columns: 2

        /******** AUTH ********/
        // Username Input
        PlasmaComponents.TextField {
            id: userNameInput
            text: lastUserName
            placeholderText: i18nd("plasma_lookandfeel_org.kde.lookandfeel", "Lietotājvārds")

            Layout.fillWidth: true
            Layout.rowSpan   : 1
            Layout.columnSpan: 2


            visible: showUsernamePrompt
            focus: showUsernamePrompt && !lastUserName //if there's a username prompt it gets focus first, otherwise password does

            onAccepted: {
                root.clearNotification = false
                root.notificationMessage = i18nd("plasma_lookandfeel_org.kde.lookandfeel","Apstrādā datus...")

                calledFrom = 'username'

                if(userNameInput.text.length == 0) {
                    initLogin(passwordBox.text)
                }else{
                    initLogin(userNameInput.text)
                }
            }
        }

        // Password Input
        PlasmaComponents.TextField {
            id: passwordBox
            Layout.fillWidth: true

            Layout.rowSpan   : 2
            Layout.columnSpan: 2

            placeholderText: i18nd("plasma_lookandfeel_org.kde.lookandfeel", "Parole")
            focus: !showUsernamePrompt || lastUserName
            echoMode: TextInput.Password
            revealPasswordButtonShown: true

            // onAccepted: startLogin()
            onAccepted: {
                root.clearNotification = false
                root.notificationMessage = i18nd("plasma_lookandfeel_org.kde.lookandfeel","Apstrādā datus...")
                
                calledFrom = 'password'
                initLogin(passwordBox.text)
            }
            
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

            placeholderText: i18nd("plasma_lookandfeel_org.kde.lookandfeel", "PIN kods")
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
            placeholderText: i18nd("plasma_lookandfeel_org.kde.lookandfeel", "Lietotājvārds")

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
            placeholderText: i18nd("plasma_lookandfeel_org.kde.lookandfeel", "Parole")

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
            placeholderText: i18nd("plasma_lookandfeel_org.kde.lookandfeel", "PIN kods")

            onAccepted: authRegister()
        }


        ////////// CHANGE PASSWORD ///////////
        // Password Input 1
        PlasmaComponents.TextField {
            id: passwordBoxChange1
            Layout.fillWidth: true

            Layout.rowSpan   : 1
            Layout.columnSpan: 2

            echoMode: TextInput.Password
            revealPasswordButtonShown: true
            text: ""
            visible: false
            placeholderText: i18nd("plasma_lookandfeel_org.kde.lookandfeel", "Vecā parole")

            onAccepted: {
                authChangePassword(passwordBoxChange1.text, passwordBoxChange2.text)
            }
        }

        // Password Input 2
        PlasmaComponents.TextField {
            id: passwordBoxChange2
            Layout.fillWidth: true

            Layout.rowSpan   : 2
            Layout.columnSpan: 2

            echoMode: TextInput.Password
            revealPasswordButtonShown: true
            text: ""
            visible: false
            placeholderText: i18nd("plasma_lookandfeel_org.kde.lookandfeel", "Jaunā parole")

            onAccepted: {
                authChangePassword(passwordBoxChange1.text, passwordBoxChange2.text)
            }
        }

        // Login Button
        PlasmaComponents.Button {
            id: loginButton
            Layout.fillWidth: true
            Layout.rowSpan   : 3
            Layout.columnSpan: 2

            text: i18nd("plasma_lookandfeel_org.kde.lookandfeel", "Pieslēgties")
            onClicked: initLogin();
        }

        // Auth Button
        PlasmaComponents.Button {
            id: authButton

            Layout.rowSpan   : 3
            Layout.columnSpan: 1

            visible: false

            text: i18nd("plasma_lookandfeel_org.kde.lookandfeel", "Autorizēties")
            onClicked: authPin();
        }

        // Register Button
        PlasmaComponents.Button {
            id: registerButton

            Layout.rowSpan   : 4
            Layout.columnSpan: 1

            visible: false

            text: i18nd("plasma_lookandfeel_org.kde.lookandfeel", "Reģistrēties")
            onClicked: authRegister();
        }

        // Change Password Button
        PlasmaComponents.Button {
            id: changePasswordButton

            Layout.rowSpan   : 4
            Layout.columnSpan: 1

            visible: false

            text: i18nd("plasma_lookandfeel_org.kde.lookandfeel", "Atjaunināt")
            onClicked: authChangePassword();
        }

        // Back
        PlasmaComponents.Button {
            id: backButton

            Layout.rowSpan   : 3
            Layout.columnSpan: 1

            visible: false

            text: i18nd("plasma_lookandfeel_org.kde.lookandfeel", "Atpakaļ")
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
        passwordBoxChange1.visible = false
        passwordBoxChange2.visible = false
        
        backButton.visible = false
        loginButton.visible = true
        authButton.visible = false
        registerButton.visible = false
        changePasswordButton.visible = false

        backButton.Layout.rowSpan = 3

        userNameInput.text = temp["username"]
        passwordBox.text = ""
        pinBox.text = ""

        passwordBox.forceActiveFocus()

        // root.notificationMessage = ""
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

        userNameInput.text = temp["username"]

        pinBox.forceActiveFocus()

        root.clearNotification = false
        root.notificationMessage = i18nd("plasma_lookandfeel_org.kde.lookandfeel","Autorizācija.")
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

        root.clearNotification = false
        root.notificationMessage = i18nd("plasma_lookandfeel_org.kde.lookandfeel","Reģistrācija.")
    }

    /**
     * Set change pass UI visual state
     */
    function changePasswordUi() {
        userNameInput.visible = false
        passwordBox.visible = false
        pinBox.visible = false

        userNameInputRegister.visible = false
        passwordBoxRegister.visible = false
        pinBoxRegister.visible = false

        loginButton.visible = false
        registerButton.visible = false

        passwordBoxChange1.text = ''
        passwordBoxChange2.text = ''

        passwordBoxChange1.visible = true
        passwordBoxChange2.visible = true
        backButton.visible = true
        changePasswordButton.visible = true

        backButton.Layout.rowSpan = 4


        passwordBoxChange1.forceActiveFocus()

        root.clearNotification = false
        root.notificationMessage = i18nd("plasma_lookandfeel_org.kde.lookandfeel","Paroles atjaunināšana.")
    }
}
