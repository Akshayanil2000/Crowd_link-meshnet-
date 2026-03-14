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
- **Frontend**: Flutter (Dart)
- **Local P2P API**: Google's Nearby Connections API
- **Global Identity & Sync**: Firebase 

### Key Dependencies
- `nearby_connections` (Local networking)
- `firebase_auth` (User authentication)
- `firebase_database` (Global sync & Friend discovery)
- `provider` (State management)
- `google_fonts` (Typography)
- `qr_flutter` (Identity generation)
- `mobile_scanner` (Mesh ID linking)
- `uuid` (Unique node tracking)
- `permission_handler` (Bluetooth/WiFi/Location permissions)

---

## 4. Design Guidelines

### Aesthetic
- **Theme**: Premium Dark / Cyberpunk Minimalist
- **Core Principle**: Deep, high-contrast interfaces with subtle glassmorphism and micro-animations.

### Color Palette
- **Background**: Pitch Black (`#000000`)
- **Surfaces**: Deep Charcoal (`#141414`)
- **Primary Accent**: Vibrant Neon Green (`#00FC82`) - used for active states, highlights, and primary buttons.
- **Inactive/Muted**: Slate Grey (`#8E8E93` or `Colors.grey[500]`)

### Typography
- **Primary Font**: `Inter` (via Google Fonts).
- **Styling**: Clean, legible, with distinct font weights for headers (Bold/600+) versus body text (Regular/400).

---

## 5. System Architecture
Modular Flutter architecture separated by domain:
- `lib/main.dart`: App entry point
- `lib/screens/`: UI Views (HomeScreen, OverviewScreen, ChatScreen, PrivateMessageScreen, ActivityScreen)
- `lib/widgets/`: Reusable components (PulseDot, MeshNodeIcon, etc.)
- `lib/theme/`: Constants and coloring (AppColors)
- `lib/services/`: API layers (NearbyConnections networking, Firebase)
- `lib/providers/`: Global state management
- `lib/models/`: Dart data structures (Message, User, Node)

---

## 6. Core Features Roadmap

### Phase 1: Frontend Infrastructure (Current)
- [x] Base Application Setup
- [x] Navigation Scaffold (Bottom Glass Bar)
- [x] Network Overview Dashboard
- [x] Chat Hub Interface
- [x] Private Direct Messaging View
- [ ] Activity / Notifications Feed

### Phase 2: Mesh Connectivity
- Setup `nearby_connections` logic to advertise and discover devices.
- Implement the automated handshaking sequence for secure offline P2P bridging.
- Broadcast message dispatching.

### Phase 3: Firebase Integration
- Cloud syncing of offline messages when an Internet Gateway node is found.
- Global identity tracking for friends.
