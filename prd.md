# Product Requirements Document (PRD): Mesh-Net (CrowdLink)

## 1. Project Overview
**Mesh-Net** (internally known as **CrowdLink**) is a decentralized communication and networking application built with Flutter. Its primary mission is to enable seamless communication, file sharing, and emergency alerts in environments where traditional internet connectivity is unavailable, unstable, or restricted.

The app leverages **Mesh Networking** technology to create a self-healing, peer-to-peer network of mobile devices that can relay information across nodes.

---

## 2. Target Audience
- **Disaster Relief Workers**: Communicating in areas where infrastructure is down.
- **Remote Adventurers**: Hikers and travelers in areas without cellular coverage.
- **Privacy-Conscious Users**: People seeking decentralized, off-grid communication methods.
- **Mass Gatherings**: Festivals or protests where cellular networks often become congested.

---

## 3. Technology Stack

### Core Frameworks
- **Frontend**: Flutter (Dart) - for cross-platform mobile development (Android & iOS).
- **Backend (Cloud)**: Firebase (Core, Auth, Realtime Database) - used for global identity, synchronization when online, and friend discovery.
- **Local Connectivity**: Google's **Nearby Connections API** - the backbone for peer-to-peer discovery and data transfer without internet.

### Key Libraries & Packages
- **Connectivity**: `nearby_connections` (Mesh networking backbone).
- **Identity**: `firebase_auth`, `firebase_database`, `uuid`.
- **UI/UX**: `google_fonts`, `qr_flutter` (QR generation), `mobile_scanner` (QR scanning).
- **State Management**: `provider`.
- **Utilities**: `permission_handler` (for Bluetooth/Location/WiFi permissions required for mesh).

---

## 4. Key Features

### 4.1. Mesh Connectivity & Discovery
- **Node-to-Node Discovery**: Automatic identification of nearby devices running Mesh-Net.
- **Network Health Monitoring**: Real-time visualization of signal strength, nearby device count, and network latency.
- **Internet Gateway**: Ability for a node with internet access to share its connection as a "gateway" for others in the mesh.

### 4.2. Identity & Social Networking
- **Mesh ID System**: Every user receives a unique, short-form Mesh ID (e.g., `MN-A3F9K2`) tied to their Firebase account.
- **QR Interaction**: Peer discovery via scanning/sharing QR codes for instant friend adding.
- **Profile Management**: Firebase-backed user profiles including names and Mesh IDs.

### 4.3. Communication
- **Direct Messaging**: One-on-one encrypted/private messaging between linked peers.
- **Mesh Broadcasting**: Sending announcements or alerts to every node within range of the mesh.
- **Offline Syncing**: Messages are queued and delivered as soon as a path (direct or across nodes) becomes available.

### 4.4. Safety & Utilities
- **SOS Alerts**: A high-priority broadcast feature for emergency situations.
- **Location Sharing**: Peer-to-peer location sharing within the mesh (even without GPS satellites/cellular data, using relative positioning or mesh gateways).

---

## 5. User Interface (UI) Design
The app follow a **"Premium Dark"** aesthetic:
- **Primary Brand Color**: Vibrant Neon Green (`#00FC82`).
- **Surface Colors**: Deep Charcoal (`#141414`) and Pitch Black (`#000000`).
- **Aesthetics**: Glassmorphism, subtle micro-animations (pulsing search icons), and high-contrast status indicators.
- **Typography**: **Inter** (via Google Fonts).
- **Navigation**: Minimalist AppBar with large typography and interactive cards.

---

## 6. Architecture & Entry Point
The project follows a modular Flutter architecture:
- **Entry Point**: `lib/main.dart` (Initializes Firebase and sets context for the `CrowdLinkApp`).
- **`lib/screens/`**: UI-focused widgets and screen layouts (e.g., `mesh_screen.dart`, `chat_screen.dart`, `home_screen.dart`).
- **`lib/services/`**: Logical abstractions for Firebase (`auth_service.dart`) and eventually the Mesh Network controller.
- **`lib/models/`**: Data structures for Users, Messages, and Mesh Nodes.
- **`lib/providers/`**: State management logic using the Provider pattern.

---

## 7. Future Roadmap
- **End-to-End Encryption**: Implementing Signal Protocol-like encryption for all mesh traffic.
- **Offline File Sharing**: Transferring large assets (photos, documents) across the mesh.
- **Multi-Hop Relay**: Dynamic routing for messages across multiple intermediate devices.
- **Anonymous Mode**: Enabling mesh communication without a formal Firebase account for maximum privacy.
