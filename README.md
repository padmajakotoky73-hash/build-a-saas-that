```markdown
# Build-a-SaaS-that 📊

Track API usage and costs for developers with this Next.js + FastAPI SaaS starter.

[![Next.js](https://img.shields.io/badge/Next.js-13.4+-black?logo=next.js)](https://nextjs.org/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.95+-green?logo=fastapi)](https://fastapi.tiangolo.com/)
[![License](https://img.shields.io/badge/License-MIT-blue)](LICENSE)

## ✨ Features

- Real-time API usage dashboard
- Cost tracking per endpoint
- Usage alerts and notifications
- Multi-project support
- Developer-friendly API analytics

## 🚀 Quick Start

1. Clone the repo:
   ```bash
   git clone https://github.com/yourusername/build-a-saas-that.git
   cd build-a-saas-that
   ```

2. Install dependencies:
   ```bash
   # Frontend
   cd frontend && npm install
   
   # Backend
   cd ../backend && pip install -r requirements.txt
   ```

## ⚙️ Environment Setup

Create `.env` files:

**Frontend (`.env.local`)**:
```env
NEXT_PUBLIC_API_URL=http://localhost:8000
```

**Backend (`.env`)**:
```env
DATABASE_URL=sqlite:///./sql_app.db
SECRET_KEY=your-secret-key-here
```

## 🛠️ Development

Run both services:

```bash
# Frontend (Next.js)
cd frontend && npm run dev

# Backend (FastAPI)
cd ../backend && uvicorn main:app --reload
```

## 🚀 Deployment

1. **Frontend**:
   ```bash
   cd frontend && npm run build && npm start
   ```

2. **Backend**:
   ```bash
   cd backend && uvicorn main:app --host 0.0.0.0 --port 8000
   ```

For production, consider using:
- Vercel/Netlify (frontend)
- Docker + Cloud Provider (backend)

## 📄 License

MIT - See [LICENSE](LICENSE) for details.
```