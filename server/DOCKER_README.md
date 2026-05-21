# Docker Setup Instructions for Your Graduation Project

## 📋 Prerequisites

- Docker installed on your system ([Download Docker](https://www.docker.com/products/docker-desktop))
- Docker Compose installed (usually comes with Docker Desktop)

## 🚀 Quick Start

### 1. Copy Docker files to your project root

Copy these files to the root directory of your graduation project:
- `Dockerfile`
- `docker-compose.yml`
- `.dockerignore`
- `.env.example`

### 2. Configure Environment Variables

1. Copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```

2. Edit `.env` and update with your actual values:
   - `POSTGRES_USER`: Your database username
   - `POSTGRES_PASSWORD`: Your database password
   - `POSTGRES_DB`: Your database name
   - Add any other environment variables your app needs

### 3. Update docker-compose.yml

Make sure to update these values in `docker-compose.yml`:
- Port numbers (if your app uses a different port than 3000)
- Database credentials (should match your .env file)
- Any additional environment variables

### 4. Build and Run

Run this command in your project root directory:

```bash
docker-compose up -d
```

This will:
- Build your Node.js application image
- Start PostgreSQL database
- Start your backend application
- Create a network for them to communicate

### 5. Verify Everything is Running

Check if containers are running:
```bash
docker-compose ps
```

View logs:
```bash
# All services
docker-compose logs -f

# Just backend
docker-compose logs -f backend

# Just database
docker-compose logs -f postgres
```

## 📝 Common Commands

### Start services
```bash
docker-compose up -d
```

### Stop services
```bash
docker-compose down
```

### Stop and remove volumes (database data)
```bash
docker-compose down -v
```

### Rebuild after code changes
```bash
docker-compose up -d --build
```

### View running containers
```bash
docker-compose ps
```

### Access backend container shell
```bash
docker exec -it graduation_project_backend sh
```

### Access PostgreSQL database
```bash
docker exec -it graduation_project_db psql -U your_db_user -d your_database_name
```

### Run database migrations (if using Sequelize/TypeORM/Prisma)
```bash
# Sequelize
docker-compose exec backend npx sequelize-cli db:migrate

# TypeORM
docker-compose exec backend npm run typeorm migration:run

# Prisma
docker-compose exec backend npx prisma migrate deploy
```

## 🔧 Troubleshooting

### Port already in use
If you get a port conflict error, change the port mapping in `docker-compose.yml`:
```yaml
ports:
  - "3001:3000"  # Change 3001 to any available port
```

### Database connection issues
Make sure the `DATABASE_URL` in docker-compose.yml matches your database credentials.

### Permission issues
On Linux, you might need to run commands with `sudo` or add your user to the docker group.

### See all logs
```bash
docker-compose logs -f
```

## 📦 What Gets Created

- **Docker Image**: A packaged version of your application
- **Containers**: Running instances of your app and database
- **Volume**: Persistent storage for your PostgreSQL data
- **Network**: Private network for your containers to communicate

## ⚠️ Important Notes

- Your original project files are **NOT modified or removed**
- Docker creates containers based on your files, but keeps originals intact
- The `volumes` section in docker-compose.yml syncs your code changes (hot reload)
- Database data persists in a Docker volume even after stopping containers
- To completely reset: `docker-compose down -v` (WARNING: deletes database data)

## 🎓 For Your Graduation Project Submission

When submitting your project, include:
1. All Docker files (Dockerfile, docker-compose.yml, .dockerignore)
2. .env.example (NOT .env - keep credentials private)
3. This README with setup instructions

Your evaluators can then run your project with just:
```bash
docker-compose up -d
```

## 📞 Need Help?

If you encounter issues:
1. Check logs: `docker-compose logs -f`
2. Verify environment variables in .env
3. Ensure Docker Desktop is running
4. Check port availability
