# VR/AR@MIT Godot XR Project Template

Features basic XR setup, dynamic controller/hand models for both hand and regular tracking, passthrough setup, and other basic scaffolds.

## 1 Template Capabilities

## 2 Installation / Setup

A set of slides also detailing this process can be found here: 

1. On Github, select the green ` <> Code ` icon, and select ` Download zip `. This will download the repository files without linking them to my repository.
2. Unzip and extract the downloaded zip in a memorable place (ex.`/home/xr-project/` or `C:\Users\name\Documents\xr-project\`).
3. Initialize a git repository in the chosen folder and set a github upstream (shared with those you are working with).
4. Open Godot and import and existing project. Navigate to your chosen location and select the `project.godot` file. This will open the project in the editor. When it loads, you should see a basic 3d scene.
5. IMPORTANT: Install the OpenXR vendors addon: Navigate to the asset store (top bar, right side) and download the Godot OpenXR Vendors Plugin. When asked, check "ignore project root".

### 2.1 Building / Deploying

#### 2.1.1 HorizonOS/Android


#### 2.1.2 PCVR
PCVR is mostly setup from the start. You can fully playtest the application with a connected headset, and building will typically require Python, SCons, or XCode depending on platform.

#### 2.1.3 VisionOS
WIP - Coming soon
