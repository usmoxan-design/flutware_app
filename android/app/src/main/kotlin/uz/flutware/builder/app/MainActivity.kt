package uz.flutware.builder.app

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.content.pm.ApplicationInfo
import android.os.Process
import android.provider.Settings
import android.util.Log
import androidx.core.content.FileProvider
import com.android.apksig.ApkSigner
import com.android.apksig.ApkVerifier
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.*
import java.security.KeyStore
import java.security.PrivateKey
import java.security.Security
import java.security.cert.X509Certificate
import org.bouncycastle.jce.provider.BouncyCastleProvider
import org.bouncycastle.asn1.x500.X500Name
import org.bouncycastle.cert.jcajce.JcaX509CertificateConverter
import org.bouncycastle.cert.jcajce.JcaX509v3CertificateBuilder
import org.bouncycastle.operator.jcajce.JcaContentSignerBuilder
import java.math.BigInteger
import java.util.Date
import java.util.zip.ZipEntry
import java.util.zip.ZipFile
import java.util.zip.ZipInputStream
import java.util.zip.ZipOutputStream
import com.reandroid.apk.ApkModule
import com.reandroid.arsc.chunk.xml.ResXmlAttribute
import com.reandroid.arsc.chunk.xml.ResXmlElement

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.flutware.builder/installer"
    private val INSTALL_ACTION = "uz.flutware.builder.app.INSTALL_RESULT"
    private var installReceiver: BroadcastReceiver? = null

    init {
        Security.addProvider(BouncyCastleProvider())
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSupportedAbis" -> {
                    val abis = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                        Build.SUPPORTED_ABIS?.toList() ?: emptyList()
                    } else {
                        val list = mutableListOf<String>()
                        if (!Build.CPU_ABI.isNullOrBlank()) list.add(Build.CPU_ABI)
                        if (!Build.CPU_ABI2.isNullOrBlank()) list.add(Build.CPU_ABI2)
                        list
                    }
                    result.success(abis)
                }
                "getAbiInfo" -> {
                    val supported = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                        Build.SUPPORTED_ABIS?.toList() ?: emptyList()
                    } else {
                        val list = mutableListOf<String>()
                        if (!Build.CPU_ABI.isNullOrBlank()) list.add(Build.CPU_ABI)
                        if (!Build.CPU_ABI2.isNullOrBlank()) list.add(Build.CPU_ABI2)
                        list
                    }
                    val abis32 = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                        Build.SUPPORTED_32_BIT_ABIS?.toList() ?: emptyList()
                    } else {
                        supported
                    }
                    val abis64 = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                        Build.SUPPORTED_64_BIT_ABIS?.toList() ?: emptyList()
                    } else {
                        emptyList()
                    }
                    val is64 = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        Process.is64Bit()
                    } else {
                        false
                    }
                    val map = mapOf(
                        "supported" to supported,
                        "abis32" to abis32,
                        "abis64" to abis64,
                        "is64Bit" to is64
                    )
                    result.success(map)
                }
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        try {
                            installApk(path)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("INSTALL_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_PATH", "Path is null", null)
                    }
                }
                "buildAndSignApk" -> {
                    val templatePath = call.argument<String>("templatePath")
                    val jsonContent = call.argument<String>("jsonContent")
                    val outputPath = call.argument<String>("outputPath")
                    val appName = call.argument<String>("appName") ?: "My App"
                    val packageName = call.argument<String>("packageName") ?: "com.example.myapp"
                    val versionCode = call.argument<String>("versionCode") ?: "1"
                    val versionName = call.argument<String>("versionName") ?: "1.0"

                    if (templatePath != null && jsonContent != null && outputPath != null) {
                        Thread {
                            try {
                                val finalPath = buildAndSignApk(
                                    templatePath, 
                                    jsonContent, 
                                    outputPath, 
                                    packageName, 
                                    versionCode, 
                                    versionName, 
                                    appName
                                )
                                runOnUiThread { result.success(finalPath) }
                            } catch (e: Exception) {
                                e.printStackTrace()
                                runOnUiThread { result.error("SIGN_ERROR", e.message, null) }
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGS", "Args are null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun buildAndSignApk(
        templatePath: String, 
        jsonContent: String, 
        outputPath: String,
        newPackageName: String,
        versionCode: String,
        versionName: String,
        appName: String
    ): String {
        val templateFile = File(templatePath)
        val tempEditApk = File(cacheDir, "temp_edit.apk") 
        val unsignedApk = File(cacheDir, "unsigned_temp.apk") 
        
        if (tempEditApk.exists()) tempEditApk.delete()
        if (unsignedApk.exists()) unsignedApk.delete()
        
        // 1. Template-ni nusxalash
        templateFile.copyTo(tempEditApk)

        // 2. Metadata tahrirlash (REAndroid)
        println("APK Metadata tahrirlash boshlandi...")
        try {
            val apkModule = ApkModule.loadApkFile(tempEditApk)
            
            // A) Manifest o'zgartirish
            val manifest = apkModule.androidManifestBlock
            val oldPackageName = manifest.packageName
            manifest.setPackageName(newPackageName)
            manifest.setVersionCode(versionCode.toIntOrNull() ?: 1)
            manifest.setVersionName(versionName)

            // testOnly/debuggable atributlarini o'chirib qo'yamiz (oddiy o'rnatish uchun)
            val manifestElement = manifest.documentElement
            if (manifestElement != null) {
                setAndroidBooleanAttr(manifestElement, "testOnly", android.R.attr.testOnly, false)
                setAndroidBooleanAttr(manifestElement, "debuggable", android.R.attr.debuggable, false)
            }

            // B) Resource Table Package yangilash (MUHIM!)
            apkModule.tableBlock?.listPackages()?.forEach { pkg ->
                if (oldPackageName != null && pkg.name == oldPackageName) {
                    pkg.setName(newPackageName)
                }
            }

            // C) App Name va Provider Authority tahrirlash
            val appElement = manifest.applicationElement
            if (appElement != null) {
                // Label (Ilova nomi) ko'p atributlar orasidan qidiramiz
                val iterator = appElement.attributes.iterator()
                while (iterator.hasNext()) {
                    val attr = iterator.next() as? ResXmlAttribute
                    if (attr != null) {
                        val name = attr.getName() ?: ""
                        if (name == "label" || name.endsWith(":label")) {
                             attr.setValueAsString(appName)
                        }
                    }
                }

                // Application darajasida ham testOnly/debuggable ni o'chiramiz
                setAndroidBooleanAttr(appElement, "testOnly", android.R.attr.testOnly, false)
                setAndroidBooleanAttr(appElement, "debuggable", android.R.attr.debuggable, false)
                // Zipalign talabini chetlab o'tish uchun native liblarni ajratib o'rnatish
                setAndroidBooleanAttr(
                    appElement,
                    "extractNativeLibs",
                    android.R.attr.extractNativeLibs,
                    true
                )

                // Providers
                appElement.listElements("provider")?.forEach { provider ->
                    val pIterator = provider.attributes.iterator()
                    while (pIterator.hasNext()) {
                        val attr = pIterator.next() as? ResXmlAttribute
                        if (attr != null) {
                            val name = attr.getName() ?: ""
                            if (name == "authorities" || name.endsWith(":authorities")) {
                                val current = attr.getValueAsString() ?: ""
                                if (current.contains(".fileprovider")) {
                                    val updated = if (!oldPackageName.isNullOrBlank() &&
                                        current.startsWith(oldPackageName)
                                    ) {
                                        current.replaceFirst(oldPackageName, newPackageName)
                                    } else {
                                        "$newPackageName.fileprovider"
                                    }
                                    attr.setValueAsString(updated)
                                }
                            }
                        }
                    }
                }
            }

            // O'zgarishlarni saqlash
            apkModule.writeApk(tempEditApk)
            apkModule.close()

        } catch (e: Exception) {
            e.printStackTrace()
        }

        // 3. JSON faylni almashtirish (Standard Java Zip)
        addJsonToApk(tempEditApk, unsignedApk, jsonContent)

        // 4. Imzolash
        signApk(unsignedApk.absolutePath, outputPath)
        // 5. Imzolangan APK ni tekshirish (xatoni aniqlash uchun)
        verifyApk(outputPath)
        // 5. APK meta ma'lumotlarini logga chiqarish
        logApkMeta(outputPath)
        
        // Tozalash
        tempEditApk.delete()
        unsignedApk.delete()
        
        return outputPath
    }

    private fun addJsonToApk(inputApk: File, outputApk: File, jsonContent: String) {
        ZipFile(inputApk).use { zip ->
            ZipOutputStream(FileOutputStream(outputApk)).use { zos ->
                val entries = zip.entries()
                while (entries.hasMoreElements()) {
                    val entry = entries.nextElement()
                    val name = entry.name
                    if (name.startsWith("META-INF/")) {
                        continue
                    }
                    if (name == "assets/flutter_assets/assets/project.json") {
                        continue
                    }

                    val outEntry = ZipEntry(name).apply {
                        time = entry.time
                        comment = entry.comment
                        extra = entry.extra
                        method = entry.method
                        if (method == ZipEntry.STORED) {
                            size = entry.size
                            crc = entry.crc
                        }
                    }

                    zos.putNextEntry(outEntry)
                    zip.getInputStream(entry).use { input ->
                        input.copyTo(zos)
                    }
                    zos.closeEntry()
                }

                val jsonEntry = ZipEntry("assets/flutter_assets/assets/project.json")
                zos.putNextEntry(jsonEntry)
                zos.write(jsonContent.toByteArray(Charsets.UTF_8))
                zos.closeEntry()
            }
        }
    }

    private fun setAndroidBooleanAttr(
        element: ResXmlElement,
        name: String,
        resId: Int,
        value: Boolean
    ) {
        val attr = element.searchAttributeByName(name)
            ?: element.getOrCreateAndroidAttribute(name, resId)
        attr.setValueAsString(if (value) "true" else "false")
    }

    private fun signApk(inputPath: String, outputPath: String) {
        val ks = getOrCreateKeystore()
        val privateKey = ks.getKey(ALIAS, PASSWORD) as PrivateKey
        val cert = ks.getCertificate(ALIAS) as X509Certificate

        val signerConfig = ApkSigner.SignerConfig.Builder(ALIAS, privateKey, listOf(cert)).build()

        val builder = ApkSigner.Builder(listOf(signerConfig))
            .setInputApk(File(inputPath))
            .setOutputApk(File(outputPath))
            // V1 + V2 + V3 imzo (keng moslik)
            .setV1SigningEnabled(true)
            .setV2SigningEnabled(true)
            .setV3SigningEnabled(true)
            .setMinSdkVersion(21)

        builder.build().sign()
    }

    private val KEYSTORE_NAME = "flutware_local.p12"
    private val PASSWORD = "flutware_secure".toCharArray()
    private val ALIAS = "flutware"

    private fun getOrCreateKeystore(): KeyStore {
        val file = File(filesDir, KEYSTORE_NAME)
        val ks = KeyStore.getInstance("PKCS12")
        
        if (file.exists()) {
            file.inputStream().use { ks.load(it, PASSWORD) }
        } else {
            ks.load(null, null)
            val kpg = java.security.KeyPairGenerator.getInstance("RSA")
            kpg.initialize(2048)
            val kp = kpg.generateKeyPair()
            
            val start = Date()
            val end = Date(start.time + 36500L * 24 * 60 * 60 * 1000)
            val dn = X500Name("CN=Flutware, O=Self, C=UZ")
            val serial = BigInteger.valueOf(System.currentTimeMillis())
            val contentSigner = JcaContentSignerBuilder("SHA256WithRSA").build(kp.private)
            val certBuilder = JcaX509v3CertificateBuilder(dn, serial, start, end, dn, kp.public)
            val cert = JcaX509CertificateConverter().getCertificate(certBuilder.build(contentSigner))
            
            ks.setKeyEntry(ALIAS, kp.private, PASSWORD, arrayOf(cert))
            file.outputStream().use { ks.store(it, PASSWORD) }
        }
        return ks
    }

    private fun installApk(path: String) {
        val apkFile = File(path)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val canInstall = packageManager.canRequestPackageInstalls()
            if (!canInstall) {
                Log.w("FlutwareInstall", "Unknown apps ruxsati yo'q, settings ochildi")
                val intent = Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName")
                )
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                return
            }
        }

        val packageInstaller = packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
        val sessionId = packageInstaller.createSession(params)
        val session = packageInstaller.openSession(sessionId)

        session.openWrite("app", 0, apkFile.length()).use { out ->
            apkFile.inputStream().use { input ->
                input.copyTo(out)
                session.fsync(out)
            }
        }

        if (installReceiver != null) {
            try {
                unregisterReceiver(installReceiver)
            } catch (_: Exception) {}
            installReceiver = null
        }

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: android.content.Context, intent: Intent) {
                val status = intent.getIntExtra(
                    PackageInstaller.EXTRA_STATUS,
                    PackageInstaller.STATUS_FAILURE
                )
                val message = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)
                val legacy = intent.getIntExtra("android.content.pm.extra.LEGACY_STATUS", Int.MIN_VALUE)

                when (status) {
                    PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                        val confirmIntent = intent.getParcelableExtra<Intent>(Intent.EXTRA_INTENT)
                        confirmIntent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        if (confirmIntent != null) {
                            startActivity(confirmIntent)
                        } else {
                            Log.e("FlutwareInstall", "User action intent topilmadi")
                        }
                    }
                    PackageInstaller.STATUS_SUCCESS -> {
                        Log.i("FlutwareInstall", "INSTALL_SUCCESS legacy=$legacy")
                    }
                    else -> {
                        Log.e("FlutwareInstall", "INSTALL_FAILED status=$status legacy=$legacy msg=$message")
                        // Fallback: system installer orqali urinib ko'ramiz
                        installApkWithIntent(path)
                    }
                }

                try {
                    unregisterReceiver(this)
                } catch (_: Exception) {}
                installReceiver = null
            }
        }

        registerReceiver(receiver, IntentFilter(INSTALL_ACTION))
        installReceiver = receiver

        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val pendingIntent = PendingIntent.getBroadcast(this, sessionId, Intent(INSTALL_ACTION), flags)
        session.commit(pendingIntent.intentSender)
        session.close()
    }

    private fun installApkWithIntent(path: String) {
        try {
            val file = File(path)
            val intent = Intent(Intent.ACTION_VIEW)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
                intent.setDataAndType(uri, "application/vnd.android.package-archive")
                intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            } else {
                intent.setDataAndType(Uri.fromFile(file), "application/vnd.android.package-archive")
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        } catch (e: Exception) {
            Log.e("FlutwareInstall", "System installer ochilmadi: ${e.message}")
        }
    }

    private fun verifyApk(path: String) {
        try {
            val result = ApkVerifier.Builder(File(path)).build().verify()
            Log.i(
                "FlutwareVerify",
                "verified=${result.isVerified} v1=${result.isVerifiedUsingV1Scheme} " +
                    "v2=${result.isVerifiedUsingV2Scheme} v3=${result.isVerifiedUsingV3Scheme}"
            )
            result.errors.forEach { err ->
                Log.e("FlutwareVerify", "ERROR: $err")
            }
            result.warnings.forEach { warn ->
                Log.w("FlutwareVerify", "WARN: $warn")
            }
        } catch (e: Exception) {
            Log.e("FlutwareVerify", "Verify xatoligi: ${e.message}")
        }
    }

    private fun logApkMeta(path: String) {
        try {
            val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getPackageArchiveInfo(
                    path,
                    PackageManager.PackageInfoFlags.of(0)
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageArchiveInfo(path, 0)
            }

            if (info == null) {
                Log.w("FlutwareMeta", "APK meta topilmadi: $path")
                return
            }

            val vCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                info.longVersionCode
            } else {
                @Suppress("DEPRECATION")
                info.versionCode.toLong()
            }

            val flags = info.applicationInfo?.flags ?: 0
            val isTestOnly = (flags and ApplicationInfo.FLAG_TEST_ONLY) != 0
            val isDebuggable = (flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
            val minSdk = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                info.applicationInfo?.minSdkVersion ?: -1
            } else {
                -1
            }
            val targetSdk = info.applicationInfo?.targetSdkVersion ?: -1
            val deviceSdk = Build.VERSION.SDK_INT
            val apkAbis = getApkAbis(path)
            val deviceAbis = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                Build.SUPPORTED_ABIS?.toList() ?: emptyList()
            } else {
                val list = mutableListOf<String>()
                if (!Build.CPU_ABI.isNullOrBlank()) list.add(Build.CPU_ABI)
                if (!Build.CPU_ABI2.isNullOrBlank()) list.add(Build.CPU_ABI2)
                list
            }

            Log.i(
                "FlutwareMeta",
                "APK META: pkg=${info.packageName} vCode=$vCode vName=${info.versionName} " +
                    "testOnly=$isTestOnly debug=$isDebuggable minSdk=$minSdk targetSdk=$targetSdk " +
                    "deviceSdk=$deviceSdk apkAbis=$apkAbis deviceAbis=$deviceAbis"
            )
        } catch (e: Exception) {
            Log.e("FlutwareMeta", "APK meta o'qishda xatolik: ${e.message}")
        }
    }

    private fun getApkAbis(path: String): List<String> {
        return try {
            val set = linkedSetOf<String>()
            ZipFile(File(path)).use { zip ->
                val entries = zip.entries()
                while (entries.hasMoreElements()) {
                    val name = entries.nextElement().name
                    if (name.startsWith("lib/")) {
                        val parts = name.split('/')
                        if (parts.size >= 2) {
                            set.add(parts[1])
                        }
                    }
                }
            }
            set.toList()
        } catch (_: Exception) {
            emptyList()
        }
    }
}
