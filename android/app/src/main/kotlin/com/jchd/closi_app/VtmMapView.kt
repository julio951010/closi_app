package com.jchd.closi_app

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.view.MotionEvent
import android.view.View
import android.view.animation.AccelerateDecelerateInterpolator
import android.widget.FrameLayout
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import kotlin.math.PI
import kotlin.math.atan
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.ln
import kotlin.math.pow
import kotlin.math.tan
import org.mapsforge.core.model.LatLong
import org.mapsforge.map.android.graphics.AndroidGraphicFactory
import org.mapsforge.map.android.util.AndroidUtil
import org.mapsforge.map.android.view.MapView
import org.mapsforge.map.layer.renderer.TileRendererLayer
import org.mapsforge.map.model.common.Observer
import org.mapsforge.map.reader.MapFile
import org.mapsforge.map.rendertheme.StreamRenderTheme
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream

class VtmMapView(
    private val context: Context,
    private val id: Int,
    private val messenger: BinaryMessenger,
    creationParams: Map<*, *>?
) : PlatformView, MethodChannel.MethodCallHandler {

    private val rootView: FrameLayout
    private val mapView: MapView
    private val pinView: PinView
    private val methodChannel: MethodChannel
    private var tileRendererLayer: TileRendererLayer? = null
    private var myLatLong: LatLong? = null
    private data class BusinessMarker(
        val lat: Double, val lon: Double,
        val nombre: String, val id: String,
        val categoria: String,
        val bitmap: Bitmap?
    )
    private val businessMarkers = mutableListOf<BusinessMarker>()
    private var selectedBusinessId: String? = null
    private var readOnly = false

    init {
        try {
            AndroidGraphicFactory.createInstance(
                context.applicationContext as android.app.Application
            )
        } catch (_: Exception) { }

        mapView = MapView(context)
        mapView.isClickable = true
        mapView.mapScaleBar.isVisible = false
        mapView.setBuiltInZoomControls(true)

        pinView = PinView(context)

        rootView = FrameLayout(context)
        rootView.addView(mapView, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        ))
        rootView.addView(pinView, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        ))

        mapView.model.mapViewPosition.addObserver(Observer { pinView.invalidate() })

        mapView.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    pinView.touchStartX = event.x
                    pinView.touchStartY = event.y
                    pinView.isDragging = false
                    false
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.x - pinView.touchStartX
                    val dy = event.y - pinView.touchStartY
                    if (dx * dx + dy * dy > 15f * 15f) {
                        pinView.isDragging = true
                    }
                    false
                }
                MotionEvent.ACTION_UP -> {
                    if (!pinView.isDragging) {
                        try {
                            processTap(event.x, event.y)
                        } catch (_: Exception) { }
                    }
                    false
                }
                else -> false
            }
        }

        methodChannel = MethodChannel(messenger, "closi_app/vtm_map_$id")
        methodChannel.setMethodCallHandler(this)

        val initLat = (creationParams?.get("lat") as? Double) ?: 23.113592
        val initLon = (creationParams?.get("lon") as? Double) ?: -82.366592
        val initZoom = (creationParams?.get("zoom") as? Int)?.toByte() ?: 13
        readOnly = (creationParams?.get("readOnly") as? Boolean) ?: false

        cargarMapa(initLat, initLon, initZoom)
    }

    override fun getView(): View = rootView

    private fun processTap(x: Float, y: Float) {
        val viewW = mapView.width.toDouble()
        val viewH = mapView.height.toDouble()
        if (viewW <= 0.0 || viewH <= 0.0) return
        val center = mapView.model.mapViewPosition.center
        val zoom = mapView.model.mapViewPosition.zoomLevel.toInt()
        val tileSize = mapView.model.displayModel.tileSize
        val mapSize = tileSize.toDouble() * 2.0.pow(zoom)
        val centerLatRad = center.latitude * PI / 180.0
        val centerWPX = (center.longitude + 180.0) / 360.0 * mapSize
        val centerWPY = (1.0 - ln(tan(centerLatRad) + 1.0 / cos(centerLatRad)) / PI) / 2.0 * mapSize

        // Check if tap hit a marker
        val hitR = 50f * context.resources.displayMetrics.density
        for (bm in businessMarkers) {
            val bmLatRad = bm.lat * PI / 180.0
            val bmWPX = (bm.lon + 180.0) / 360.0 * mapSize
            val bmWPY = (1.0 - ln(tan(bmLatRad) + 1.0 / cos(bmLatRad)) / PI) / 2.0 * mapSize
            val bx = (mapView.width / 2.0 + (bmWPX - centerWPX)).toFloat()
            val by = (mapView.height / 2.0 + (bmWPY - centerWPY)).toFloat()
            if (Math.abs(x - bx) <= hitR && Math.abs(y - by) <= hitR) {
                methodChannel.invokeMethod("onMarkerTapped", mapOf("id" to bm.id))
                return
            }
        }

        val dx = x.toDouble() - viewW / 2.0
        val dy = y.toDouble() - viewH / 2.0
        val touchWPX = centerWPX + dx
        val touchWPY = centerWPY + dy
        val touchLon = touchWPX / mapSize * 360.0 - 180.0
        val mercN = PI * (1.0 - 2.0 * touchWPY / mapSize)
        val touchLatRad = atan((exp(mercN) - exp(-mercN)) / 2.0)
        val touchLat = touchLatRad * 180.0 / PI
        val latLong = LatLong(touchLat, touchLon)
        mapView.setCenter(latLong)
        methodChannel.invokeMethod(
            "onMapClicked",
            mapOf<String, Any?>("lat" to touchLat, "lon" to touchLon)
        )
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setCenter" -> {
                val lat = call.argument<Double>("lat") ?: return
                val lon = call.argument<Double>("lon") ?: return
                mapView.setCenter(LatLong(lat, lon))
                result.success(null)
            }
            "setZoom" -> {
                val zoom = call.argument<Int>("zoom") ?: return
                mapView.setZoomLevel(zoom.toByte())
                result.success(null)
            }
            "getCenter" -> {
                val center = mapView.model.mapViewPosition.center
                result.success(mapOf("lat" to center.latitude, "lon" to center.longitude))
            }
            "placePin" -> {
                val lat = call.argument<Double>("lat") ?: return
                val lon = call.argument<Double>("lon") ?: return
                val imageBytes = call.argument<ByteArray>("imageBytes")
                val selected = call.argument<Boolean>("isSelected") ?: false
                pinView.pinLatLong = LatLong(lat, lon)
                pinView.pinSelected = selected
                pinView.pinBitmap = if (imageBytes != null) {
                    BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)
                } else null
                pinView.invalidate()
                result.success(null)
            }
            "clearPin" -> {
                pinView.pinLatLong = null
                pinView.pinBitmap = null
                pinView.pinSelected = false
                pinView.invalidate()
                result.success(null)
            }
            "selectBusiness" -> {
                val id = call.argument<String>("id")
                selectedBusinessId = id
                if (id != null) pinView.startGlow() else pinView.stopGlow()
                pinView.invalidate()
                result.success(null)
            }
            "setMyLocation" -> {
                val lat = call.argument<Double>("lat") ?: return
                val lon = call.argument<Double>("lon") ?: return
                myLatLong = LatLong(lat, lon)
                pinView.invalidate()
                result.success(null)
            }
            "clearMyLocation" -> {
                myLatLong = null
                pinView.invalidate()
                result.success(null)
            }
            "setMarkers" -> {
                val lista = call.argument<List<Map<String, Any?>>>("markers")
                businessMarkers.clear()
                if (lista != null) {
                    for (m in lista) {
                        val lat = m["lat"] as? Double ?: continue
                        val lon = m["lon"] as? Double ?: continue
                        val nombre = m["nombre"] as? String ?: ""
                        val id = m["id"] as? String ?: ""
                        val categoria = m["categoria"] as? String ?: ""
                        val imageBytes = m["imageBytes"] as? ByteArray
                        val bmp = if (imageBytes != null) {
                            val opts = BitmapFactory.Options().apply { inSampleSize = 2 }
                            BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size, opts)
                        } else null
                        businessMarkers.add(BusinessMarker(lat, lon, nombre, id, categoria, bmp))
                    }
                }
                pinView.invalidate()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun cargarMapa(lat: Double, lon: Double, zoom: Byte) {
        try {
            val mapFile = copiarAsset("flutter_assets/assets/maps/cuba.map", "cuba.map")

            val tileCache = AndroidUtil.createTileCache(
                context, "maincache",
                mapView.model.displayModel.tileSize, 1f,
                mapView.model.frameBufferModel.overdrawFactor
            )

            val layer = TileRendererLayer(
                tileCache, MapFile(mapFile),
                mapView.model.mapViewPosition,
                AndroidGraphicFactory.INSTANCE
            )

            val temaStream: InputStream =
                context.assets.open("flutter_assets/assets/maps/osmarender.xml")
            layer.setXmlRenderTheme(StreamRenderTheme("/", temaStream))

            tileRendererLayer = layer
            mapView.layerManager.layers.add(layer)

            mapView.setCenter(LatLong(lat, lon))
            mapView.setZoomLevel(zoom)

        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun copiarAsset(assetPath: String, nombreArchivo: String): File {
        val mapDir = File(context.filesDir, "closi_maps")
        if (!mapDir.exists()) mapDir.mkdirs()
        val destino = File(mapDir, nombreArchivo)
        if (!destino.exists()) {
            val input = context.assets.open(assetPath)
            val output = FileOutputStream(destino)
            input.copyTo(output)
            input.close()
            output.close()
        }
        return destino
    }

    override fun dispose() {
        tileRendererLayer?.onDestroy()
        mapView.destroyAll()
        methodChannel.setMethodCallHandler(null)
    }

    private inner class PinView(context: Context) : View(context) {
        var pinLatLong: LatLong? = null
        var pinBitmap: Bitmap? = null
        var pinSelected = false
        var touchStartX = 0f
        var touchStartY = 0f
        var isDragging = false
        private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG)
        private val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG)
        private val pinPath = Path()
        private val clipPath = Path()
        private val imgRect = RectF()
        private val density: Float
        private var glowProgress = 0.3f
        private val glowAnimator = ValueAnimator.ofFloat(0.3f, 1.0f).apply {
            duration = 1000
            repeatMode = ValueAnimator.REVERSE
            repeatCount = ValueAnimator.INFINITE
            interpolator = AccelerateDecelerateInterpolator()
            addUpdateListener {
                glowProgress = animatedValue as Float
                invalidate()
            }
        }

        init {
            fillPaint.style = Paint.Style.FILL
            strokePaint.style = Paint.Style.STROKE
            density = context.resources.displayMetrics.density
        }

        fun startGlow() {
            if (!glowAnimator.isStarted) glowAnimator.start()
        }

        fun stopGlow() {
            glowAnimator.cancel()
            glowProgress = 0.3f
            invalidate()
        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            if (width <= 0 || height <= 0) return

            val zoom = mapView.model.mapViewPosition.zoomLevel.toInt()
            val tileSize = mapView.model.displayModel.tileSize
            val mapSize = tileSize.toDouble() * 2.0.pow(zoom)
            val center = mapView.model.mapViewPosition.center

            val centerLatRad = center.latitude * PI / 180.0
            val centerWPX = (center.longitude + 180.0) / 360.0 * mapSize
            val centerWPY =
                (1.0 - ln(tan(centerLatRad) + 1.0 / cos(centerLatRad)) / PI) / 2.0 * mapSize

            // My location blue dot
            val myPos = myLatLong
            if (myPos != null) {
                val myLatRad = myPos.latitude * PI / 180.0
                val myWPX = (myPos.longitude + 180.0) / 360.0 * mapSize
                val myWPY = (1.0 - ln(tan(myLatRad) + 1.0 / cos(myLatRad)) / PI) / 2.0 * mapSize
                val mx = (width / 2.0 + (myWPX - centerWPX)).toFloat()
                val my = (height / 2.0 + (myWPY - centerWPY)).toFloat()
                val mr = 12f
                fillPaint.color = Color.argb(30, 33, 150, 243)
                canvas.drawCircle(mx, my, mr * 2.2f, fillPaint)
                fillPaint.color = Color.WHITE
                canvas.drawCircle(mx, my, mr, fillPaint)
                fillPaint.color = Color.parseColor("#2196F3")
                canvas.drawCircle(mx, my, mr * 0.7f, fillPaint)
            }

            // Business markers — modern circles with image
            var selectedBm: BusinessMarker? = null
            for (bm in businessMarkers) {
                if (bm.id == selectedBusinessId) {
                    selectedBm = bm
                    continue
                }
                val bmLatRad = bm.lat * PI / 180.0
                val bmWPX = (bm.lon + 180.0) / 360.0 * mapSize
                val bmWPY = (1.0 - ln(tan(bmLatRad) + 1.0 / cos(bmLatRad)) / PI) / 2.0 * mapSize
                val bx = (width / 2.0 + (bmWPX - centerWPX)).toFloat()
                val by = (height / 2.0 + (bmWPY - centerWPY)).toFloat()
                drawMarker(canvas, bx, by, 18f * density, bm, false)
            }
            // Selected marker on top with glow
            if (selectedBm != null) {
                val bmLatRad = selectedBm.lat * PI / 180.0
                val bmWPX = (selectedBm.lon + 180.0) / 360.0 * mapSize
                val bmWPY = (1.0 - ln(tan(bmLatRad) + 1.0 / cos(bmLatRad)) / PI) / 2.0 * mapSize
                val bx = (width / 2.0 + (bmWPX - centerWPX)).toFloat()
                val by = (height / 2.0 + (bmWPY - centerWPY)).toFloat()
                drawMarker(canvas, bx, by, 22f * density, selectedBm, true)
            }

            // Teardrop pin
            val pos = pinLatLong ?: return
            val pinLatRad = pos.latitude * PI / 180.0
            val pinWPX = (pos.longitude + 180.0) / 360.0 * mapSize
            val pinWPY =
                (1.0 - ln(tan(pinLatRad) + 1.0 / cos(pinLatRad)) / PI) / 2.0 * mapSize

            val sx = (width / 2.0 + (pinWPX - centerWPX)).toFloat()
            val sy = (height / 2.0 + (pinWPY - centerWPY)).toFloat()

            val dp = density
            val sel = if (pinSelected) 1.12f else 1f
            val bodyR = 15f * dp * sel
            val tipH = 12f * dp * sel
            val imgR = 14f * dp
            val borde = 2.5f * dp

            // Teardrop path — anchor at bottom tip (sx, sy)
            pinPath.reset()
            pinPath.moveTo(sx, sy - 2.3f * bodyR - tipH)
            pinPath.cubicTo(
                sx - 1.3f * bodyR, sy - 2.3f * bodyR - tipH,
                sx - 1.5f * bodyR, sy - 0.2f * bodyR - tipH,
                sx - 0.7f * bodyR, sy + 0.2f * bodyR - tipH
            )
            pinPath.lineTo(sx - 6f * dp * sel, sy - tipH * 0.5f)
            pinPath.lineTo(sx, sy)
            pinPath.lineTo(sx + 6f * dp * sel, sy - tipH * 0.5f)
            pinPath.lineTo(sx + 0.7f * bodyR, sy + 0.2f * bodyR - tipH)
            pinPath.cubicTo(
                sx + 1.5f * bodyR, sy - 0.2f * bodyR - tipH,
                sx + 1.3f * bodyR, sy - 2.3f * bodyR - tipH,
                sx, sy - 2.3f * bodyR - tipH
            )
            pinPath.close()

            // Shadow beneath pin
            fillPaint.color = Color.argb(50, 0, 0, 0)
            canvas.drawOval(sx - bodyR * 0.5f, sy + 4f * dp, sx + bodyR * 0.5f, sy + 10f * dp, fillPaint)

            // Pin body — red teardrop
            fillPaint.color = Color.parseColor(if (pinSelected) "#FF1A1A" else "#FF3B30")
            canvas.drawPath(pinPath, fillPaint)

            // White border around teardrop
            strokePaint.color = Color.WHITE
            strokePaint.strokeWidth = borde
            canvas.drawPath(pinPath, strokePaint)

            // Image cutout — center of the circular head
            val imgCx = sx
            val imgCy = sy - tipH - 1.05f * bodyR

            // White disc behind image (the "hole")
            fillPaint.color = Color.WHITE
            canvas.drawCircle(imgCx, imgCy, imgR + borde, fillPaint)

            val bmp = pinBitmap
            if (bmp != null) {
                clipPath.reset()
                clipPath.addCircle(imgCx, imgCy, imgR, Path.Direction.CW)
                canvas.save()
                canvas.clipPath(clipPath)
                imgRect.set(imgCx - imgR, imgCy - imgR, imgCx + imgR, imgCy + imgR)
                canvas.drawBitmap(bmp, null, imgRect, null)
                canvas.restore()
            } else {
                fillPaint.color = Color.parseColor("#F5F5F5")
                canvas.drawCircle(imgCx, imgCy, imgR, fillPaint)
                fillPaint.color = Color.parseColor("#BDBDBD")
                canvas.drawCircle(imgCx, imgCy, imgR * 0.35f, fillPaint)
            }

            // White border around image circle
            strokePaint.color = Color.WHITE
            strokePaint.strokeWidth = borde
            canvas.drawCircle(imgCx, imgCy, imgR, strokePaint)
        }

        private fun drawMarker(canvas: Canvas, bx: Float, by: Float, radius: Float,
                                bm: BusinessMarker, selected: Boolean) {
            val dp = density

            if (selected) {
                val g = glowProgress
                val alpha1 = (g * 55).toInt().coerceIn(0, 255)
                val alpha2 = (g * 80).toInt().coerceIn(0, 255)
                val rMul = 1.6f + g * 1.0f

                fillPaint.color = Color.argb(alpha1, 33, 150, 243)
                canvas.drawCircle(bx, by, radius * rMul, fillPaint)
                fillPaint.color = Color.argb(alpha2, 33, 150, 243)
                canvas.drawCircle(bx, by, radius * (rMul - 0.4f), fillPaint)
            }

            // Shadow
            fillPaint.color = Color.argb(40, 0, 0, 0)
            canvas.drawCircle(bx, by + 2f * dp, radius * 0.85f, fillPaint)

            // White base
            fillPaint.color = Color.WHITE
            canvas.drawCircle(bx, by, radius, fillPaint)

            val bmp = bm.bitmap
            if (bmp != null) {
                clipPath.reset()
                clipPath.addCircle(bx, by, radius - 2f * dp, Path.Direction.CW)
                canvas.save()
                canvas.clipPath(clipPath)
                imgRect.set(bx - radius + 2f * dp, by - radius + 2f * dp,
                    bx + radius - 2f * dp, by + radius - 2f * dp)
                canvas.drawBitmap(bmp, null, imgRect, null)
                canvas.restore()
            } else {
                val hue = (bm.id.hashCode() and 0x7FFFFFFF) % 360
                fillPaint.color = Color.HSVToColor(floatArrayOf(hue.toFloat(), 0.55f, 0.85f))
                canvas.drawCircle(bx, by, radius - 2f * dp, fillPaint)
            }

            // Circle border
            strokePaint.color = Color.WHITE
            strokePaint.strokeWidth = 2f * dp
            canvas.drawCircle(bx, by, radius, strokePaint)
        }
    }
}
