# TripC - Travel Companion

Your intelligent travel planning companion built with Next.js and Node.js.

## Current repository layout

- `Project/` contains the existing Next.js travel platform and backend reference.
- `mobile/` contains the native Flutter hotel-booking app being rebuilt from the web experience.
- The migration reuses existing backend access and does not add backend APIs or schema. See the [canonical Flutter migration spec](_bmad-output/specs/spec-flutter-mobile-migration/SPEC.md).
- Release order: complete the agreed Flutter features, pass acceptance, then build and verify the release APK.

## 🚀 Getting Started

### Prerequisites

- Node.js 18+
- npm or yarn
- Python 3.8+ (for Python services)

### Installation

1. **Clone the repository**
   ```bash
   git clone <your-repo-url>
   cd TripC_Remade
   ```

2. **Install dependencies**
   ```bash
   npm install
   # or
   yarn install
   ```

3. **Set up environment variables**
   ```bash
   cp .env.local .env.local
   # Edit .env.local with your configuration
   ```

4. **Run the development server**
   ```bash
   npm run dev
   # or
   yarn dev
   ```

   Open [http://localhost:3000](http://localhost:3000) with your browser.

### Python Services Setup

```bash
cd python_services
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

## 📁 Project Structure

```
TripC_Remade/
├── app/                    # Next.js app directory
│   ├── api/               # API routes
│   ├── layout.tsx         # Root layout
│   ├── page.tsx           # Home page
│   └── globals.css        # Global styles
├── components/            # React components
│   ├── ui/               # UI components (Button, Card, etc.)
│   └── layout/           # Layout components (Navbar, Footer)
├── lib/                   # Utility functions
│   ├── api.ts            # API utilities
│   ├── utils.ts          # General utilities
│   └── db.ts             # Database configuration
├── store/                 # State management
├── context/               # React context providers
│   └── AuthContext.tsx   # Authentication context
├── types/                 # TypeScript type definitions
│   └── index.ts          # Global types
├── config/                # Configuration files
│   └── app.config.ts     # App configuration
├── public/                # Static assets
├── styles/                # Additional styles
├── python_services/       # Python microservices
│   ├── requirements.txt  # Python dependencies
│   └── README.md         # Python services documentation
├── .env.local            # Environment variables
├── next.config.js        # Next.js configuration
├── tailwind.config.js    # Tailwind CSS configuration
├── tsconfig.json         # TypeScript configuration
└── package.json          # Node.js dependencies
```

## 🛠️ Tech Stack

### Frontend
- **Next.js 14** - React framework with App Router
- **TypeScript** - Type-safe JavaScript
- **Tailwind CSS** - Utility-first CSS framework
- **React** - UI library

### Backend
- **Next.js API Routes** - Serverless API endpoints
- **Python Services** - Additional backend services

### Development Tools
- **ESLint** - Code linting
- **PostCSS** - CSS processing
- **Autoprefixer** - CSS vendor prefixing

## 📝 Available Scripts

```bash
npm run dev      # Start development server
npm run build    # Build for production
npm run start    # Start production server
npm run lint     # Run ESLint
```

## 🎨 Components

### UI Components
- `Button` - Reusable button component with variants
- `Card` - Card container component

### Layout Components
- `Navbar` - Navigation bar
- `Footer` - Footer component

## 🔧 Configuration

### Environment Variables

Create a `.env.local` file in the root directory:

```env
DATABASE_URL=
NEXT_PUBLIC_API_URL=
NEXTAUTH_SECRET=
NEXTAUTH_URL=
```

### Path Aliases

The project uses TypeScript path aliases for cleaner imports:

```typescript
import { Button } from '@/components/ui/Button'
import { api } from '@/lib/api'
import { Trip } from '@/types'
```

## 📦 Key Features

- ✅ Modern Next.js 14 with App Router
- ✅ TypeScript for type safety
- ✅ Tailwind CSS for styling
- ✅ Component-based architecture
- ✅ API routes for backend
- ✅ Python services integration
- ✅ Authentication context
- ✅ Responsive design
- ✅ ESLint configuration

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License.

## 👥 Authors

- Your Name

## 🙏 Acknowledgments

- Next.js team for the amazing framework
- Tailwind CSS for the utility-first CSS framework
- Vercel for hosting and deployment
