/**
 * Debug component
 * We already have to struggle with SDDM QML, at least let's have some simple debugging tools. T___T
 * @author richardev
 */

import QtQuick 2.6
import QtQuick.Layouts 1.2
import QtQuick.Controls 2.0
import org.kde.plasma.components 2.0 as PlasmaComponents

Rectangle {
    property int setWidth: 330
    property int setHeight: 330
    property int nr: 1

    id: root
    visible: true
    y:20
    x:20

    width: root.setWidth
    height: root.setHeight

    color: "transparent"

    Rectangle {
        id: titleBar
        visible: true
        width: setWidth
        height: 40
        y: 0
        x: 0

        color: "#7418fb"

        Text {
            color: "#dfc9ff"
            text: "Debug <b>" + colorText("PAMPy NFC", "#ffffff") + "</b> <i>"  + colorText("@richardev", "#ffffff") + "</i>"
            font.pixelSize: 14
            anchors.centerIn: parent
            // y:5
        }
    }

    Rectangle {
        clip: true
        color: "#16171b"
        width: root.setWidth
        height: root.setHeight
        y: 40

        Text {
            id: content
            color: Qt.rgba(255,255,255,0.75)
            font.pixelSize: 12
            padding: 10
            text: ""
            y: -scrollBar.position * height
        }

        ScrollBar {
            id: scrollBar
            active: true
            orientation: Qt.Vertical
            size: root.height/ (content.height+40)
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            policy: ScrollBar.AlwaysOn
            padding: 10
        }
    }

    function log(cat, text, block) {
        var borderColor = "#333333"
        var nrColor = "#666666"
        var catColor = "#999999"
        var textColor = "#ffffff"
        var newText = ""

        if(cat.indexOf("info") !== -1) {
            catColor = "#7418fb"
            textColor = "#dfc9ff"
        }

        if(cat.indexOf("error") !== -1) {
            catColor = "#fb1891"
            textColor = "#fccce6"
        }

        if(cat.indexOf("success") !== -1) {
            catColor = "#18fba8"
            textColor = "#ccffec"
        }

        if(block == true) newText += "<br/>" + colorText("╔═══════════════════════════════════════════╗",borderColor) + "<br/>"
        if(block == true) newText += colorText("║", borderColor) + " "
        newText += colorText("[" + root.nr + "]", nrColor) + "<b>" + colorText("[" + cat + "]", catColor) + "</b> <i>" + colorText(text, textColor) + "</i><br/>"
        if(block == true) newText += colorText("╚═══════════════════════════════════════════╝",borderColor) + "<br/><br/>"

        content.text = newText + content.text

        root.nr += 1
    }

    function colorText(text, color) {
        return "<font color=\"" + color + "\">" + text + "</font>"
    }
}
// Rectangle {
// 	property int setWidth: 330
// 	property int setHeight: 330

//     id: root
//     visible: true

//     clip: true
//     color: "#16171b"
//     width: root.setWidth
//     height: root.setHeight
//     y: 40

//     Rectangle {
//     	id: titleBar
//     	visible: true
//         width: setWidth
//         height: 40

// 	    color: "#7418fb"

//     	Text {
// 	    	color: "#ffffff"
// 	    	text: "Debug Bar for PAMPy NFC by @richardev"
// 	    	font.pixelSize: 14
// 	    	font.bold: true
//             anchors.centerIn: parent
// 	    }
//     }

//     Text {
//         id: content
//         color: Qt.rgba(255,255,255,0.75)
//         font.pixelSize: 12
//         text: "testing\ntesting 123\ntesting\ntesting 123\ntesting\ntesting 123\ntesting\ntesting 123\ntesting\ntesting 123\ntesting\ntesting 123\ntesting\ntesting 123\ntesting\ntesting 123\ntesting\ntesting 123\ntesting\ntesting 123\ntesting\ntesting 123\ntesting\ntesting 123\n"
//         y: (-scrollBar.position * height) + 34
//     }

//     ScrollBar {
//         id: scrollBar
//         active: true
//         orientation: Qt.Vertical
//         size: (root.height - 40)/ content.height
//         anchors.top: parent.top
//         anchors.right: parent.right
//         anchors.bottom: parent.bottom
//     }
// }