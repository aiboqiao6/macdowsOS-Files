/* Dependency-free vector fallback for toolbar/state icons and missing assets. */
import QtQuick 6.5

Item {
    id: root

    property string name: ""
    property color color: "#dce7f8"
    property real strokeWidth: 1.7
    implicitWidth: 18
    implicitHeight: 18

    function repaint() { iconCanvas.requestPaint() }
    onNameChanged: repaint()
    onColorChanged: repaint()
    onStrokeWidthChanged: repaint()

    Canvas {
        id: iconCanvas
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        // Normalized geometry keeps the same drawing usable at any pixel size.
        function line(ctx, x1, y1, x2, y2) {
            ctx.moveTo(width * x1, height * y1)
            ctx.lineTo(width * x2, height * y2)
        }
        function circle(ctx, x, y, radius) {
            ctx.moveTo(width * (x + radius), height * y)
            ctx.arc(width * x, height * y, Math.min(width, height) * radius, 0, Math.PI * 2)
        }
        function roundedRect(ctx, x, y, w, h, radius) {
            var px = width * x
            var py = height * y
            var pw = width * w
            var ph = height * h
            var pr = Math.min(width, height) * radius
            ctx.moveTo(px + pr, py)
            ctx.lineTo(px + pw - pr, py)
            ctx.arcTo(px + pw, py, px + pw, py + pr, pr)
            ctx.lineTo(px + pw, py + ph - pr)
            ctx.arcTo(px + pw, py + ph, px + pw - pr, py + ph, pr)
            ctx.lineTo(px + pr, py + ph)
            ctx.arcTo(px, py + ph, px, py + ph - pr, pr)
            ctx.lineTo(px, py + pr)
            ctx.arcTo(px, py, px + pr, py, pr)
        }

        // The name property selects the icon geometry below.
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.strokeStyle = root.color
            ctx.fillStyle = root.color
            ctx.lineWidth = root.strokeWidth
            ctx.lineCap = "round"
            ctx.lineJoin = "round"
            ctx.beginPath()

            if (root.name === "search") {
                circle(ctx, 0.43, 0.43, 0.25)
                line(ctx, 0.61, 0.61, 0.84, 0.84)
                ctx.stroke()
            } else if (root.name === "list") {
                line(ctx, 0.33, 0.28, 0.84, 0.28)
                line(ctx, 0.33, 0.50, 0.84, 0.50)
                line(ctx, 0.33, 0.72, 0.84, 0.72)
                ctx.stroke()
                ctx.beginPath()
                circle(ctx, 0.17, 0.28, 0.045)
                circle(ctx, 0.17, 0.50, 0.045)
                circle(ctx, 0.17, 0.72, 0.045)
                ctx.fill()
            } else if (root.name === "grid") {
                roundedRect(ctx, 0.16, 0.16, 0.28, 0.28, 0.035)
                roundedRect(ctx, 0.56, 0.16, 0.28, 0.28, 0.035)
                roundedRect(ctx, 0.16, 0.56, 0.28, 0.28, 0.035)
                roundedRect(ctx, 0.56, 0.56, 0.28, 0.28, 0.035)
                ctx.stroke()
            } else if (root.name === "share") {
                line(ctx, 0.50, 0.08, 0.50, 0.60)
                line(ctx, 0.33, 0.25, 0.50, 0.08)
                line(ctx, 0.50, 0.08, 0.67, 0.25)
                line(ctx, 0.28, 0.38, 0.20, 0.38)
                line(ctx, 0.20, 0.38, 0.20, 0.87)
                line(ctx, 0.20, 0.87, 0.80, 0.87)
                line(ctx, 0.80, 0.87, 0.80, 0.38)
                line(ctx, 0.80, 0.38, 0.72, 0.38)
                ctx.stroke()
            } else if (root.name === "trash") {
                line(ctx, 0.30, 0.30, 0.70, 0.30)
                line(ctx, 0.42, 0.20, 0.58, 0.20)
                roundedRect(ctx, 0.35, 0.34, 0.30, 0.47, 0.04)
                line(ctx, 0.45, 0.43, 0.45, 0.70)
                line(ctx, 0.55, 0.43, 0.55, 0.70)
                ctx.stroke()
            } else if (root.name === "more") {
                circle(ctx, 0.22, 0.50, 0.07)
                circle(ctx, 0.50, 0.50, 0.07)
                circle(ctx, 0.78, 0.50, 0.07)
                ctx.fill()
            } else if (root.name === "home") {
                line(ctx, 0.18, 0.48, 0.50, 0.20)
                line(ctx, 0.50, 0.20, 0.82, 0.48)
                line(ctx, 0.27, 0.42, 0.27, 0.82)
                line(ctx, 0.73, 0.42, 0.73, 0.82)
                line(ctx, 0.27, 0.82, 0.73, 0.82)
                line(ctx, 0.44, 0.82, 0.44, 0.60)
                line(ctx, 0.44, 0.60, 0.56, 0.60)
                line(ctx, 0.56, 0.60, 0.56, 0.82)
                ctx.stroke()
            } else if (root.name === "folder") {
                roundedRect(ctx, 0.14, 0.28, 0.72, 0.50, 0.06)
                line(ctx, 0.18, 0.28, 0.18, 0.20)
                line(ctx, 0.18, 0.20, 0.45, 0.20)
                line(ctx, 0.45, 0.20, 0.52, 0.28)
                ctx.stroke()
            } else if (root.name === "file") {
                line(ctx, 0.28, 0.14, 0.60, 0.14)
                line(ctx, 0.60, 0.14, 0.74, 0.28)
                line(ctx, 0.74, 0.28, 0.74, 0.86)
                line(ctx, 0.74, 0.86, 0.28, 0.86)
                line(ctx, 0.28, 0.86, 0.28, 0.14)
                line(ctx, 0.60, 0.14, 0.60, 0.28)
                line(ctx, 0.60, 0.28, 0.74, 0.28)
                ctx.stroke()
            } else if (root.name === "drive") {
                roundedRect(ctx, 0.12, 0.25, 0.76, 0.50, 0.08)
                line(ctx, 0.22, 0.58, 0.78, 0.58)
                circle(ctx, 0.28, 0.42, 0.035)
                circle(ctx, 0.72, 0.42, 0.035)
                ctx.stroke()
            } else if (root.name === "chevron-right") {
                line(ctx, 0.38, 0.22, 0.64, 0.50)
                line(ctx, 0.64, 0.50, 0.38, 0.78)
                ctx.stroke()
            } else if (root.name === "chevron-up") {
                line(ctx, 0.22, 0.64, 0.50, 0.36)
                line(ctx, 0.50, 0.36, 0.78, 0.64)
                ctx.stroke()
            } else if (root.name === "chevron-left") {
                line(ctx, 0.62, 0.22, 0.36, 0.50)
                line(ctx, 0.36, 0.50, 0.62, 0.78)
                ctx.stroke()
            } else if (root.name === "chevron-down") {
                line(ctx, 0.22, 0.36, 0.50, 0.64)
                line(ctx, 0.50, 0.64, 0.78, 0.36)
                ctx.stroke()
            } else if (root.name === "recent") {
                circle(ctx, 0.50, 0.50, 0.38)
                line(ctx, 0.50, 0.25, 0.50, 0.50)
                line(ctx, 0.50, 0.50, 0.31, 0.50)
                ctx.stroke()
            } else if (root.name === "desktop") {
                roundedRect(ctx, 0.10, 0.20, 0.80, 0.60, 0.07)
                line(ctx, 0.10, 0.34, 0.90, 0.34)
                ctx.stroke()
            } else if (root.name === "document") {
                line(ctx, 0.24, 0.10, 0.61, 0.10)
                line(ctx, 0.61, 0.10, 0.80, 0.30)
                line(ctx, 0.80, 0.30, 0.80, 0.90)
                line(ctx, 0.80, 0.90, 0.24, 0.90)
                line(ctx, 0.24, 0.90, 0.24, 0.10)
                line(ctx, 0.61, 0.10, 0.61, 0.30)
                line(ctx, 0.61, 0.30, 0.80, 0.30)
                ctx.stroke()
            } else if (root.name === "download") {
                circle(ctx, 0.50, 0.50, 0.38)
                line(ctx, 0.50, 0.25, 0.50, 0.69)
                line(ctx, 0.34, 0.53, 0.50, 0.69)
                line(ctx, 0.50, 0.69, 0.66, 0.53)
                ctx.stroke()
            } else if (root.name === "picture") {
                roundedRect(ctx, 0.08, 0.16, 0.84, 0.68, 0.04)
                circle(ctx, 0.31, 0.36, 0.07)
                line(ctx, 0.12, 0.77, 0.39, 0.53)
                line(ctx, 0.39, 0.53, 0.56, 0.66)
                line(ctx, 0.56, 0.66, 0.73, 0.46)
                line(ctx, 0.73, 0.46, 0.89, 0.65)
                ctx.stroke()
            } else if (root.name === "music") {
                line(ctx, 0.40, 0.70, 0.40, 0.22)
                line(ctx, 0.40, 0.22, 0.80, 0.12)
                line(ctx, 0.80, 0.12, 0.80, 0.60)
                line(ctx, 0.40, 0.36, 0.80, 0.26)
                circle(ctx, 0.28, 0.75, 0.12)
                circle(ctx, 0.68, 0.65, 0.12)
                ctx.stroke()
            } else if (root.name === "video") {
                roundedRect(ctx, 0.08, 0.16, 0.84, 0.68, 0.04)
                line(ctx, 0.27, 0.16, 0.27, 0.84)
                line(ctx, 0.73, 0.16, 0.73, 0.84)
                for (var i = 0; i < 3; ++i) {
                    line(ctx, 0.08, 0.32 + i * 0.18, 0.27, 0.32 + i * 0.18)
                    line(ctx, 0.73, 0.32 + i * 0.18, 0.92, 0.32 + i * 0.18)
                }
                ctx.stroke()
            } else if (root.name === "people") {
                circle(ctx, 0.36, 0.31, 0.14)
                circle(ctx, 0.75, 0.27, 0.11)
                ctx.moveTo(width * 0.08, height * 0.82)
                ctx.bezierCurveTo(width * 0.08, height * 0.49, width * 0.64, height * 0.49, width * 0.64, height * 0.82)
                ctx.closePath()
                ctx.moveTo(width * 0.69, height * 0.56)
                ctx.bezierCurveTo(width * 0.91, height * 0.52, width * 0.94, height * 0.65, width * 0.94, height * 0.80)
                line(ctx, 0.94, 0.80, 0.76, 0.80)
                ctx.stroke()
            } else if (root.name === "preview") {
                roundedRect(ctx, 0.10, 0.17, 0.80, 0.66, 0.04)
                line(ctx, 0.61, 0.17, 0.61, 0.83)
                ctx.stroke()
            } else if (root.name === "sort") {
                for (var j = 0; j < 3; ++j) {
                    roundedRect(ctx, 0.12 + j * 0.28, 0.12, 0.18, 0.18, 0.02)
                    roundedRect(ctx, 0.12 + j * 0.28, 0.43, 0.18, 0.18, 0.02)
                }
                line(ctx, 0.12, 0.80, 0.58, 0.80)
                ctx.stroke()
            } else if (root.name === "plus" || root.name === "minus" || root.name === "close") {
                if (root.name === "close") {
                    line(ctx, 0.25, 0.25, 0.75, 0.75)
                    line(ctx, 0.75, 0.25, 0.25, 0.75)
                } else {
                    line(ctx, 0.20, 0.50, 0.80, 0.50)
                    if (root.name === "plus") line(ctx, 0.50, 0.20, 0.50, 0.80)
                }
                ctx.stroke()
            } else if (root.name === "expand") {
                line(ctx, 0.17, 0.55, 0.17, 0.17)
                line(ctx, 0.17, 0.17, 0.55, 0.17)
                line(ctx, 0.83, 0.45, 0.83, 0.83)
                line(ctx, 0.83, 0.83, 0.45, 0.83)
                ctx.stroke()
            }
        }

        Component.onCompleted: requestPaint()
    }
}
