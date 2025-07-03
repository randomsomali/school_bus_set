# Fingerprint System

A comprehensive fingerprint-based attendance system with Flutter frontend and Node.js backend.

## Features

### Authentication

- Login system for both admin and parent users
- Role-based access control
- Secure token-based authentication

### User Management (Admin Only)

- **Create Users**: Add new parent or admin users with phone number and password
- **View Users**: List all users with their roles and creation dates
- **Edit Users**: Update user phone numbers, passwords, and roles
- **Delete Users**: Remove users from the system

### Student Management

- **Admin**: Full CRUD operations (Create, Read, Update, Delete)
  - Create students with assigned parents
  - View all students with fingerprint IDs and parent information
  - Edit student names and parent assignments
  - Delete students
- **Parent**: Read-only access to their own students
  - View only their children's information
  - No create, edit, or delete permissions

## Backend API

### User Endpoints

- `GET /api/users` - Get all users (admin only)
- `POST /api/users` - Create new user (admin only)
- `PUT /api/users/:id` - Update user (admin only)
- `DELETE /api/users/:id` - Delete user (admin only)

### Student Endpoints

- `GET /api/students` - Get all students (admin only)
- `POST /api/students` - Create new student (admin only)
- `PUT /api/students/:id` - Update student (admin only)
- `DELETE /api/students/:id` - Delete student (admin only)
- `GET /api/students/parent/:parentId` - Get students by parent (parent access)

## Setup Instructions

### Backend Setup

1. Navigate to the backend directory:

   ```bash
   cd backend
   ```

2. Install dependencies:

   ```bash
   npm install
   ```

3. Set up environment variables in `config/env.js`

4. Start the server:
   ```bash
   npm start
   ```

### Frontend Setup

1. Navigate to the app directory:

   ```bash
   cd app
   ```

2. Install dependencies:

   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

## Default Admin Account

- Phone: `1234567890`
- Password: `admin123`

## Usage

### Admin Features

1. **User Management**: Access the Users tab to manage all system users
2. **Student Management**: Access the Students tab to manage all students
3. **Full CRUD Operations**: Create, read, update, and delete both users and students

### Parent Features

1. **View Students**: Access the Students tab to view only their children
2. **Read-only Access**: No modification capabilities

## Security Features

- Role-based access control
- JWT token authentication
- Password hashing with bcrypt
- Input validation with Zod schemas
- Protected API endpoints

## Technologies Used

- **Frontend**: Flutter, Provider state management
- **Backend**: Node.js, Express.js, MongoDB
- **Authentication**: JWT tokens
- **Validation**: Zod schemas
- **HTTP Client**: Dio for Flutter
