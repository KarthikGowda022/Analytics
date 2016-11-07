Intuit Analytics Library
===================
#### **Step 1**: Obtaining the Framework

#### <i class="icon-download"></i> Use Bamba (Recommended)
Add **Bamba** into your Xcode project: https://github.intuit.com/CTO-DevMobileOpenSource/Bamba
Run the Bamba script to generate a default **bambaFile**.
Edit the bambaFile to reference the Intuit Analytics Library and DeviceInfoLibrary (see example below).
```
DEPENDENCIES="
IntuitAnalytics 0.0.0.99-SNAPSHOT
DeviceInfoLibrary 0.0.0.99-SNAPSHOT
"
...
```
Run **bamba.sh** once you have configured the bambaFile.
The downloaded frameworks can be found in the **Dependencies** folder.

#### <i class="icon-download"></i> Download the Framework Manually

The Intuit Analytics Library can be found at:
* [Snapshots] (http://iapps.corp.intuit.net/nexus/content/repositories/Intuit.Shared.iOS-snapshots/com/intuit/scs/IntuitAnalytics/)
* [Releases](http://iapps.corp.intuit.net/nexus/content/repositories/Intuit.Shared.iOS-releases/com/intuit/scs/IntuitAnalytics/) (no release has been made yet)

> **Note**: If you chose this path, you are on your own for integrating this framework into your iOS project as you would integrate any framework library.

#### **Step 2**: Integrating the Framework
> **Note**: If you downloaded the framework manually in Step 1, **you are on your own**.  These integration steps are specific to using Bamba to integrate this library into your app.

Once you have obtained the framework binaries, you are ready to integrate the binaries into your iOS app.  The following instructions are a less detailed version of this [Wiki](https://wiki.intuit.com/pages/viewpage.action?pageId=285073496).

 1. Open the **Dependencies** folder created by Bamba in your project root folder.
 2. Open the IntuitAnalytics folder.  You will see a symlink and two child folders in there.
 3. Drag the **IntuitAnalytics.framework symlink** to the **Embedded Binaries** section of your App Target.
 4. Go back to the Dependencies folder and open the DeviceInfoLibrary folder.
 5. Drag the **DeviceInfoLibrary.framework** to the **Embedded Binaries** section of your App Target.
 6. Add the following as a **Run Script** to the **Build Phases** of your App Target:
  ```
set -e
set -x
 
# Space separated list of libraries used
GEN_DYLIBS="IntuitAnalytics DeviceInfoLibrary"
GEN_CTO_LOCAL_REPO="/tmp/LocalDyLibRepo/"
 
cd "${SRCROOT}/Dependencies"
 
for DYLIB in ${GEN_DYLIBS}; do
  DYLIBFOLDER="${DYLIB}"
  DYLIBFRAMEWORK="${DYLIB}.framework"
 
 
  if [ -h "${GEN_CTO_LOCAL_REPO}${DYLIBFOLDER}" ]; then
    if [ -d "${DYLIBFOLDER}" ] ; then
      rm -rf "${DYLIBFOLDER}"
    fi
    cp -r "${GEN_CTO_LOCAL_REPO}${DYLIBFOLDER}" .
  fi
 
 
  cd "${DYLIBFOLDER}"
 
 
  if [ -h "${DYLIBFRAMEWORK}" -o -d "${DYLIBFRAMEWORK}" ]; then
    rm -r "${DYLIBFRAMEWORK}"
  fi
 
 
  ln -s "${PLATFORM_NAME}/${DYLIBFRAMEWORK}/" "${DYLIBFRAMEWORK}"
 
 
  cd ..
 
 
done
 
exit 0;
```
> **Note**: If you're having difficulty, please see detailed instructions [here](https://wiki.intuit.com/pages/viewpage.action?pageId=285073496).

#### **Step 3**: Using the Framework
Once you have integrated Intuit Analytics into your app, you are ready to start using the library.  First, you will need to create a configuration for use with the Intuit Analytics Library.

**Creating an IAConfiguration**
```
IAConfiguration *configuration = [[IAConfiguration alloc] init];
configuration.intuitIntegrationHostname = @"trinity-prfqdc.intuit.com"; // Used the E2E server for testing
configuration.intuitIntegrationTopic = @"your-trinity-topic-here";      // Specify your Trinity topic 
configuration.appId = @"com.intuit.MyIntuitApp";                        // Reverse-domain app identifier    
configuration.appName = @"My Intuit App";                               // Customer-facing name of the app
configuration.appVersion = @"App Version";                              // Application version for this mobile app
configuration.uniqueId = @"myUniqueId";                                 // An identifier that uniquely represents this user
configuration.deviceId = @"deviceId"                                    // A unique device id from Device Identity Service
configuration.debug = YES;                                              // Turns on/off debug logging
configuration.debugLogLevel = LogLevelDebug;                            // Levels: LogLevelError, LogLevelInfo, LogLevelDebug
```

**Instantiating the Intuit Analytics Library**
```
self.intuitAnalytics = [[IntuitAnalytics alloc] initWithConfiguration:configuration];
```
> It is recommended that you create this instance in your AppDelegate so that analytics events can be handled as soon as your application starts up.

**Tracking an Event**
```
[self.intuitAnalytics trackEvent:@"Your Event Name"];   // Basic event tracking call that has no associated properties

[self.analytics trackEvent:@"" properties:@{ @"key" : @"value" }]; // Event tracking with associated properties
```

