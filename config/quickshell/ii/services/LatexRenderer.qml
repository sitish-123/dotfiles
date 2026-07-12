pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common.functions
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Renders LaTeX snippets with MicroTeX.
 * For every request:
 *   1. Hash it
 *   2. Check if the hash is already processed
 *   3. If not, render it with MicroTeX and mark as processed
 */
Singleton {
    id: root
    
    readonly property var renderPadding: 4 // This is to prevent cutoff in the rendered images

    property list<string> processedHashes: []
    property var processedExpressions: ({})
    property var renderedImagePaths: ({})
    property string microtexBinaryDir: "/opt/MicroTeX"
    property string microtexBinaryName: "LaTeX"
    property string latexOutputPath: Directories.latexOutput

    signal renderFinished(string hash, string imagePath)

    /**
    * Requests rendering of a LaTeX expression.
    * Returns the [hash, isNew]
    */
    function requestRender(expression) {
        // 1. Hash it and initialize necessary variables
        const hash = Qt.md5(expression)
        const imagePath = `${latexOutputPath}/${hash}.svg`
        
        // 2. Check if the hash is already processed
        if (processedHashes.includes(hash)) {
            // console.log("Already processed: " + hash)
            renderFinished(hash, imagePath)
            return [hash, false]
        } else {
            root.processedHashes.push(hash)
            root.processedExpressions[hash] = expression
            // console.log("Rendering expression: " + expression)
        }

        // 3. Render with MicroTeX. Pass the expression as a PROPERTY via createObject,
        // NOT by interpolating it into a QML source string. The old Qt.createQmlObject
        // approach shell-escaped the expression but then embedded it in a double-quoted
        // QML string literal — a `"` or newline in the expression (LaTeX from AI-relayed
        // chat content) broke out of that literal and injected QML/JS. As a property the
        // value is passed verbatim; only the shell layer needs escaping (below).
        microtexProcessComponent.createObject(root, {
            expr: expression,
            hash: hash,
            imagePath: imagePath,
        })
        return [hash, true]
    }

    Component {
        id: microtexProcessComponent
        Process {
            id: microtexProcess
            property string expr: ""
            property string hash: ""
            property string imagePath: ""
            running: true
            command: [ "bash", "-c",
                `cd ${root.microtexBinaryDir} && ./${root.microtexBinaryName} -headless `
                + `'-input=${StringUtils.shellSingleQuoteEscape(StringUtils.escapeBackslashes(microtexProcess.expr))}' `
                + `'-output=${microtexProcess.imagePath}' `
                + `'-textsize=${Appearance.font.pixelSize.normal}' `
                + `'-padding=${root.renderPadding}' `
                + `'-foreground=${Appearance.colors.colOnLayer1}' `
                + `-maxwidth=0.85`
            ]
            onExited: (exitCode, exitStatus) => {
                root.renderedImagePaths[microtexProcess.hash] = microtexProcess.imagePath
                root.renderFinished(microtexProcess.hash, microtexProcess.imagePath)
                microtexProcess.destroy()
            }
        }
    }
}