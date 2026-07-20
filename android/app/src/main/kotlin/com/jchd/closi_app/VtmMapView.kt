package com.jchd.closi_app

import android.animation.ValueAnimator
import android.content.Context
import android.view.View
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Paint
import android.widget.FrameLayout
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import org.oscim.android.MapView
import org.oscim.android.canvas.AndroidBitmap
import org.oscim.core.GeoPoint
import org.oscim.core.MapPosition
import org.oscim.layers.marker.ItemizedLayer
import org.oscim.layers.marker.MarkerInterface
import org.oscim.layers.marker.MarkerItem
import org.oscim.layers.marker.MarkerSymbol
import org.oscim.layers.tile.buildings.BuildingLayer
import org.oscim.layers.tile.vector.labeling.LabelLayer
import org.oscim.theme.StreamRenderTheme
import org.oscim.tiling.source.mapfile.MapFileTileSource
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

class VtmMapView(
    private val context: Context,
    private val id: Int,
    private val messenger: BinaryMessenger,
    creationParams: Map<*, *>?
) : PlatformView, MethodChannel.MethodCallHandler {

    private val rootView: FrameLayout
    private val mapView: MapView
    private val methodChannel: MethodChannel
    private var readOnly = false
    private val markerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }

    // Marker layers for rendering (VTM GL layers)
    private val businessLayer: ItemizedLayer
    private val selectedLayer: ItemizedLayer
    private val defaultSymbol: MarkerSymbol

    // Hit-testing list (independent of VTM layer state)
    private data class BusinessMarker(
        val id: String, val nombre: String,
        val lat: Double, val lon: Double
    )
    private val businessMarkers = mutableListOf<BusinessMarker>()

    // Location marker rendered as MarkerItem (always on top)
    private val myLocationLayer: ItemizedLayer
    private var myLocationItem: MarkerItem? = null
    private var locationEnabled = false
    private var locationLat = 0.0
    private var locationLon = 0.0
    private var pulseAnimator: ValueAnimator? = null
    private var pulseProgress = 0f

    // Tile layer (needed for LabelLayer & BuildingLayer)
    private var tileLayer: org.oscim.layers.tile.vector.VectorTileLayer? = null

    // Selection pin (single marker)
    private var pinItem: MarkerItem? = null
    private var pinSymbol: MarkerSymbol? = null

    // Selected business ID
    private var selectedBusinessId: String? = null
    private var touchDownX = 0f
    private var touchDownY = 0f

    // Market colors by ID hash
    private fun markerColorFor(id: String): Int {
        val hue = (id.hashCode() and 0x7FFFFFFF) % 360
        val hsv = floatArrayOf(hue.toFloat(), 0.55f, 0.85f)
        return Color.HSVToColor(hsv)
    }

    private fun createCircleBitmap(sizeDp: Int, color: Int, selected: Boolean = false): android.graphics.Bitmap {
        val density = context.resources.displayMetrics.density
        val size = (sizeDp * density).toInt()
        val bmp = android.graphics.Bitmap.createBitmap(size, size, android.graphics.Bitmap.Config.ARGB_8888)
        val canvas = android.graphics.Canvas(bmp)
        val cx = size / 2f
        val cy = size / 2f
        val r = cx - 2f * density

        if (selected) {
            markerPaint.color = Color.argb(80, 33, 150, 243)
            canvas.drawCircle(cx, cy, r + 10f * density, markerPaint)
            markerPaint.color = Color.argb(140, 33, 150, 243)
            canvas.drawCircle(cx, cy, r + 5f * density, markerPaint)
            markerPaint.style = Paint.Style.STROKE
            markerPaint.strokeWidth = 3f * density
            markerPaint.color = Color.argb(200, 33, 150, 243)
            canvas.drawCircle(cx, cy, r, markerPaint)
            markerPaint.style = Paint.Style.FILL
        }

        markerPaint.color = Color.argb(40, 0, 0, 0)
        canvas.drawCircle(cx, cy + 2f * density, r * 0.85f, markerPaint)

        markerPaint.color = Color.WHITE
        canvas.drawCircle(cx, cy, r, markerPaint)

        markerPaint.color = color
        canvas.drawCircle(cx, cy, r - 2f * density, markerPaint)

        return bmp
    }

    private fun createDefaultSymbol(): MarkerSymbol {
        val bmp = createCircleBitmap(36, Color.parseColor("#1245A8"))
        return MarkerSymbol(AndroidBitmap(bmp), MarkerSymbol.HotspotPlace.CENTER)
    }

    init {
        mapView = MapView(context)
        rootView = FrameLayout(context)
        rootView.addView(mapView, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        ))

        methodChannel = MethodChannel(messenger, "closi_app/vtm_map_$id")
        methodChannel.setMethodCallHandler(this)

        val initLat = (creationParams?.get("lat") as? Double) ?: 23.113592
        val initLon = (creationParams?.get("lon") as? Double) ?: -82.366592
        val initZoom = (creationParams?.get("zoom") as? Int) ?: 13
        readOnly = (creationParams?.get("readOnly") as? Boolean) ?: false
        val initTheme = (creationParams?.get("theme") as? String) ?: "default"

        cargarMapa(initLat, initLon, initZoom, initTheme)

        defaultSymbol = createDefaultSymbol()

        businessLayer = ItemizedLayer(mapView.map(), mutableListOf(), defaultSymbol, null)
        mapView.map().layers().add(businessLayer)
        selectedLayer = ItemizedLayer(mapView.map(), mutableListOf(), defaultSymbol, null)
        mapView.map().layers().add(selectedLayer)

        myLocationLayer = ItemizedLayer(mapView.map(), mutableListOf(), defaultSymbol, null)
        mapView.map().layers().add(myLocationLayer)

        mapView.setOnTouchListener { _, event ->
            if (readOnly) return@setOnTouchListener false
            when (event.action) {
                android.view.MotionEvent.ACTION_DOWN -> {
                    touchDownX = event.x
                    touchDownY = event.y
                }
                android.view.MotionEvent.ACTION_UP -> {
                    val dx = event.x - touchDownX
                    val dy = event.y - touchDownY
                    val dist = Math.sqrt((dx * dx + dy * dy).toDouble())
                    if (dist < 20f * context.resources.displayMetrics.density) {
                        processTap(event.x, event.y)
                    }
                }
            }
            false
        }
    }

    override fun getView(): View = rootView

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setCenter" -> {
                val lat = call.argument<Double>("lat") ?: return
                val lon = call.argument<Double>("lon") ?: return
                val pos = MapPosition()
                mapView.map().getMapPosition(pos)
                mapView.map().setMapPosition(lat, lon, pos.scale)
                result.success(null)
            }
            "setZoom" -> {
                val zoom = call.argument<Int>("zoom") ?: return
                val pos = MapPosition()
                mapView.map().getMapPosition(pos)
                mapView.map().setMapPosition(
                    pos.geoPoint?.latitude ?: 0.0,
                    pos.geoPoint?.longitude ?: 0.0,
                    (1 shl zoom).toDouble()
                )
                result.success(null)
            }
            "getCenter" -> {
                val pos = MapPosition()
                mapView.map().getMapPosition(pos)
                result.success(mapOf(
                    "lat" to (pos.geoPoint?.latitude ?: 0.0),
                    "lon" to (pos.geoPoint?.longitude ?: 0.0)
                ))
            }
            "placePin" -> {
                val lat = call.argument<Double>("lat") ?: return
                val lon = call.argument<Double>("lon") ?: return
                val imageBytes = call.argument<ByteArray>("imageBytes")
                val selected = call.argument<Boolean>("isSelected") ?: false
                placePin(lat, lon, imageBytes, selected)
                result.success(null)
            }
            "clearPin" -> {
                clearPin()
                result.success(null)
            }
            "selectBusiness" -> {
                val id = call.argument<String>("id")
                selectBusiness(id)
                result.success(null)
            }
            "setMyLocation" -> {
                val lat = call.argument<Double>("lat") ?: return
                val lon = call.argument<Double>("lon") ?: return
                myLatLong = GeoPoint(lat, lon)
                updateMyLocation(lat, lon)
                result.success(null)
            }
            "clearMyLocation" -> {
                myLatLong = null
                pulseAnimator?.cancel()
                pulseAnimator = null
                myLocationItem?.let { myLocationLayer.removeItem(it) }
                myLocationItem = null
                locationEnabled = false
                myLocationLayer.update()
                mapView.map().updateMap(true)
                result.success(null)
            }
            "setTheme" -> {
                val tema = call.argument<String>("theme") ?: return
                aplicarTema(tema)
                result.success(null)
            }
            "setMarkers" -> {
                val lista = call.argument<List<Map<String, Any?>>>("markers")
                setMarkers(lista)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private var myLatLong: GeoPoint? = null

    private fun createMyLocationBitmap(density: Float, bearing: Float, pulse: Float = 0f): android.graphics.Bitmap {
        val size = (32f * density).toInt()
        val cx = size / 2f
        val cy = size / 2f
        val r = cx - 2f * density
        val bmp = android.graphics.Bitmap.createBitmap(size, size, android.graphics.Bitmap.Config.ARGB_8888)
        val c = android.graphics.Canvas(bmp)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)

        // Outer pulsing ring
        val pulseR = r + (r * 0.4f * pulse)
        val pulseAlpha = (25 * (1f - pulse * 0.8f)).toInt().coerceIn(5, 25)
        paint.style = Paint.Style.FILL
        paint.color = Color.argb(pulseAlpha, 33, 150, 243)
        c.drawCircle(cx, cy, pulseR, paint)
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 2f * density
        paint.color = Color.argb((80 * (1f - pulse * 0.7f)).toInt().coerceIn(10, 80), 33, 150, 243)
        c.drawCircle(cx, cy, r, paint)

        // White inner circle
        paint.style = Paint.Style.FILL
        paint.color = Color.WHITE
        c.drawCircle(cx, cy, r * 0.5f, paint)

        // Blue dot center
        paint.color = Color.parseColor("#1245A8")
        c.drawCircle(cx, cy, r * 0.35f, paint)

        // Direction arrow if bearing is valid
        if (bearing > 0f) {
            val arrowR = r * 0.65f
            paint.style = Paint.Style.FILL
            paint.color = Color.parseColor("#1245A8")
            c.save()
            c.rotate(bearing, cx, cy)
            val path = android.graphics.Path()
            path.moveTo(cx, cy - arrowR)
            path.lineTo(cx - 6f * density, cy - arrowR * 0.4f)
            path.lineTo(cx + 6f * density, cy - arrowR * 0.4f)
            path.close()
            c.drawPath(path, paint)
            c.restore()
        }
        return bmp
    }

    private fun updateMyLocation(lat: Double, lon: Double) {
        locationLat = lat
        locationLon = lon
        pulseAnimator?.cancel()
        pulseProgress = 0f
        redrawMyLocation()
        pulseAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 1800
            repeatMode = ValueAnimator.REVERSE
            repeatCount = ValueAnimator.INFINITE
            addUpdateListener { anim ->
                pulseProgress = anim.animatedValue as Float
                redrawMyLocation()
            }
            start()
        }
    }

    private fun redrawMyLocation() {
        val density = context.resources.displayMetrics.density
        val bmp = createMyLocationBitmap(density, 0f, pulseProgress)
        val sym = MarkerSymbol(AndroidBitmap(bmp), MarkerSymbol.HotspotPlace.CENTER)
        myLocationItem?.let { myLocationLayer.removeItem(it) }
        val item = MarkerItem("__location__", "", "", GeoPoint(locationLat, locationLon))
        item.setMarker(sym)
        myLocationLayer.addItem(item)
        myLocationItem = item
        locationEnabled = true
        myLocationLayer.update()
        mapView.map().updateMap(true)
    }

    private fun processTap(x: Float, y: Float) {
        if (mapView.width <= 0 || mapView.height <= 0) return
        val hitR = 18f * context.resources.displayMetrics.density
        val point = org.oscim.core.Point()
        for (bm in businessMarkers) {
            mapView.map().viewport().toScreenPoint(GeoPoint(bm.lat, bm.lon), false, point)
            if (Math.abs(x - point.x.toFloat()) <= hitR && Math.abs(y - point.y.toFloat()) <= hitR) {
                methodChannel.invokeMethod("onMarkerTapped", mapOf("id" to bm.id))
                return
            }
        }
        val gp = mapView.map().viewport().fromScreenPoint(x, y) ?: return
        methodChannel.invokeMethod("onMapClicked", mapOf("lat" to gp.latitude, "lon" to gp.longitude))
    }

    private fun placePin(lat: Double, lon: Double, imageBytes: ByteArray?, selected: Boolean) {
        val density = context.resources.displayMetrics.density
        val bmp = if (imageBytes != null) {
            val opts = BitmapFactory.Options().apply { inSampleSize = 2 }
            val src = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size, opts)
            createPinBitmap(src, selected, density)
        } else {
            createPinBitmap(null, selected, density)
        }
        pinSymbol = MarkerSymbol(AndroidBitmap(bmp), MarkerSymbol.HotspotPlace.BOTTOM_CENTER)

        pinItem?.let { selectedLayer.removeItem(it) }
        pinItem = null

        val item = MarkerItem("pin", "", "", GeoPoint(lat, lon))
        item.setMarker(pinSymbol)
        selectedLayer.addItem(item)
        pinItem = item
        selectedLayer.update()
        mapView.map().updateMap(true)
    }

    private fun createPinBitmap(photo: android.graphics.Bitmap?, selected: Boolean, density: Float): android.graphics.Bitmap {
        val sel = if (selected) 1.12f else 1f
        val pinW = (36f * density * sel).toInt()
        val shadowPad = (8f * density).toInt()

        val src = run {
            val stream = context.assets.open("flutter_assets/assets/images/red-marker.png")
            try {
                val s = BitmapFactory.decodeStream(stream)
                s ?: android.graphics.Bitmap.createBitmap(1, 1, android.graphics.Bitmap.Config.ARGB_8888)
            } catch (e: Exception) {
                android.graphics.Bitmap.createBitmap(1, 1, android.graphics.Bitmap.Config.ARGB_8888)
            } finally {
                stream.close()
            }
        }
        val aspect = src.height.toFloat() / src.width.toFloat()
        val pw = pinW
        val ph = (pw * aspect).toInt()
        val pin = android.graphics.Bitmap.createScaledBitmap(src, pw, ph, true)

        val w = pw + shadowPad * 2
        val h = ph + shadowPad
        val bmp = android.graphics.Bitmap.createBitmap(w, h, android.graphics.Bitmap.Config.ARGB_8888)
        val c = android.graphics.Canvas(bmp)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)

        // Shadow below pin
        paint.style = Paint.Style.FILL
        paint.color = Color.argb(50, 0, 0, 0)
        val sw = pw * 0.5f
        val sh = 6f * density
        c.drawOval(android.graphics.RectF((w - sw) / 2f, h - sh - 2f, (w + sw) / 2f, h - 2f), paint)

        // Draw pin
        c.drawBitmap(pin, shadowPad.toFloat(), (shadowPad * 0.3f).toFloat(), null)

        // Selected glow
        if (selected) {
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = 3f * density
            paint.color = Color.argb(180, 33, 150, 243)
            c.drawRect(shadowPad - 2f - paint.strokeWidth, (shadowPad * 0.3f) - 2f - paint.strokeWidth,
                (shadowPad + pw).toFloat() + 2f + paint.strokeWidth,
                (shadowPad * 0.3f + ph).toFloat() + 2f + paint.strokeWidth, paint)
        }

        // Photo overlay in upper area
        if (photo != null) {
            val photoPad = (4f * density).toFloat()
            val maxPhotoW = pw - photoPad * 2
            val maxPhotoH = ph * 0.45f
            val photoR = kotlin.math.min(maxPhotoW, maxPhotoH) / 2f
            val photoCx = w / 2f
            val photoCy = (shadowPad * 0.3f + ph * 0.28f).toFloat()

            val clipPath = android.graphics.Path().apply {
                addCircle(photoCx, photoCy, photoR, android.graphics.Path.Direction.CW)
            }
            c.save()
            c.clipPath(clipPath)
            paint.style = Paint.Style.FILL
            paint.color = Color.WHITE
            c.drawCircle(photoCx, photoCy, photoR, paint)
            c.drawBitmap(photo, null,
                android.graphics.RectF(photoCx - photoR, photoCy - photoR, photoCx + photoR, photoCy + photoR), null)
            c.restore()
            paint.style = Paint.Style.STROKE
            paint.color = Color.WHITE
            paint.strokeWidth = 1.5f * density
            c.drawCircle(photoCx, photoCy, photoR, paint)
        }

        return bmp
    }

    private fun clearPin() {
        pinItem?.let { selectedLayer.removeItem(it) }
        pinItem = null
        pinSymbol = null
        selectedLayer.update()
    }

    private fun selectBusiness(id: String?) {
        android.util.Log.d("VtmMap", "selectBusiness id=$id items=${businessLayer.itemList.size}")
        selectedBusinessId = id
        updateSelectedMarker()
    }

    private fun updateSelectedMarker() {
        android.util.Log.d("VtmMap", "updateSelectedMarker sel=$selectedBusinessId items=${businessLayer.itemList.size}")
        val copy = ArrayList(businessLayer.itemList)
        val changed = copy.isNotEmpty()
        var selectedItem: MarkerItem? = null

        // Move previously selected item back to businessLayer
        val prevSelected = mutableListOf<MarkerInterface>()
        for (item in selectedLayer.itemList) prevSelected.add(item)
        for (item in prevSelected) {
            selectedLayer.removeItem(item)
            if (item is MarkerItem) {
                val uidStr = item.uid?.toString()
                if (!uidStr.isNullOrEmpty() && uidStr != "pin") {
                    businessLayer.addItem(item)
                }
            }
        }

        for (item in copy) {
            if (item !is MarkerItem) continue
            val uidStr = item.uid?.toString()
            if (uidStr.isNullOrEmpty() || uidStr == "pin" || uidStr == "__location__") continue
            val isSelected = uidStr == selectedBusinessId
            val color = markerColorFor(uidStr)
            val bmp = createCircleBitmap(if (isSelected) 40 else 36, color, isSelected)
            item.setMarker(MarkerSymbol(AndroidBitmap(bmp), MarkerSymbol.HotspotPlace.CENTER))
            if (isSelected) {
                selectedItem = item
            }
        }
        // Move selected marker to top layer so it draws above everything
        if (selectedItem != null) {
            businessLayer.removeItem(selectedItem)
            selectedLayer.addItem(selectedItem)
        }
        if (changed) {
            selectedLayer.update()
            businessLayer.update()
            mapView.map().updateMap(true)
        }
    }

    private fun setMarkers(lista: List<Map<String, Any?>>?) {
        businessMarkers.clear()
        val toRemove = mutableListOf<MarkerInterface>()
        for (item in businessLayer.itemList) {
            val uid = (item as? MarkerItem)?.uid?.toString()
            if (uid != "pin" && uid != "__location__") toRemove.add(item)
        }
        for (item in toRemove) businessLayer.removeItem(item)
        val toRemoveSel = mutableListOf<MarkerInterface>()
        for (item in selectedLayer.itemList) toRemoveSel.add(item)
        for (item in toRemoveSel) selectedLayer.removeItem(item)

        if (lista != null) {
            for (m in lista) {
                val lat = m["lat"] as? Double ?: continue
                val lon = m["lon"] as? Double ?: continue
                val nombre = m["nombre"] as? String ?: ""
                val id = m["id"] as? String ?: ""
                val imageBytes = m["imageBytes"] as? ByteArray

                businessMarkers.add(BusinessMarker(id, nombre, lat, lon))

                val gp = GeoPoint(lat, lon)
                val item = MarkerItem(id, nombre, "", gp)
                val bmp = if (imageBytes != null) {
                    val opts = BitmapFactory.Options().apply { inSampleSize = 2 }
                    val src = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size, opts)
                    createCircleBitmap(36, markerColorFor(id)).let { circle ->
                        val composite = android.graphics.Bitmap.createBitmap(circle.width, circle.height, android.graphics.Bitmap.Config.ARGB_8888)
                        val c = android.graphics.Canvas(composite)
                        val r = circle.width / 2f
                        c.drawBitmap(circle, 0f, 0f, null)
                        val clip = android.graphics.Path().apply {
                            addCircle(r, r, r - 4f, android.graphics.Path.Direction.CW)
                        }
                        c.save()
                        c.clipPath(clip)
                        val s = (r - 4f) * 2f / Math.max(src.width, src.height)
                        val sw = src.width * s
                        val sh = src.height * s
                        c.drawBitmap(src, r - sw / 2f, r - sh / 2f, null)
                        c.restore()
                        composite
                    }
                } else {
                    createCircleBitmap(36, markerColorFor(id))
                }
                item.setMarker(MarkerSymbol(AndroidBitmap(bmp), MarkerSymbol.HotspotPlace.CENTER))
                businessLayer.addItem(item)
            }
        }
        updateSelectedMarker()
    }

    private fun cargarMapa(lat: Double, lon: Double, zoom: Int, tema: String) {
        try {
            val mapFile = copiarAsset("flutter_assets/assets/maps/cuba.map", "cuba.map")
            val tileSource = MapFileTileSource()
            val fis = FileInputStream(mapFile)
            tileSource.setMapFileInputStream(fis)
            tileLayer = mapView.map().setBaseMap(tileSource) as? org.oscim.layers.tile.vector.VectorTileLayer
            tileLayer?.let { tl ->
                mapView.map().layers().add(BuildingLayer(mapView.map(), tl))
                mapView.map().layers().add(LabelLayer(mapView.map(), tl))
            }
            aplicarTema(tema)
            mapView.map().setMapPosition(lat, lon, (1 shl zoom).toDouble())
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun aplicarTema(tema: String) {
        try {
            val stream = context.assets.open("vtm/$tema.xml")
            val theme = StreamRenderTheme("", stream)
            mapView.map().setTheme(theme)
            android.util.Log.d("VtmMap", "Tema aplicado: $tema")
        } catch (e: Exception) {
            android.util.Log.e("VtmMap", "Error al aplicar tema $tema: $e")
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
        pulseAnimator?.cancel()
        mapView.onPause()
        mapView.map().destroy()
        methodChannel.setMethodCallHandler(null)
    }
}
