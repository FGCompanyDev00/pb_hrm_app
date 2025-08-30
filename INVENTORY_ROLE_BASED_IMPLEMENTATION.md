# Role-Based Inventory Management System Implementation

## Overview
This document describes the implementation of a role-based inventory management system for the PB HRM application. The system automatically detects user roles and displays different interfaces based on the user's permissions.

## Architecture

### 1. User Role Service (`lib/services/user_role_service.dart`)
- **Purpose**: Centralized service for checking user roles and authentication
- **Key Methods**:
  - `getCurrentUserRoles()`: Fetches user roles from `/api/display/me` endpoint
  - `hasRole(String role)`: Checks if user has a specific role
  - `isAdminHQ()`: Specifically checks for AdminHQ role
  - `getCurrentUserId()`: Gets current user ID

### 2. Role-Based Routing
The main inventory management page (`inventory_management_page.dart`) now:
- Checks user role on initialization
- Automatically redirects AdminHQ users to the specialized AdminHQ interface
- Maintains the original interface for regular users

### 3. AdminHQ-Specific Implementation

#### Main Page (`lib/home/dashboard/Card/inventory/admin_hq/inventory_admin_hq_page.dart`)
- **Header**: Changed from "Action Menu" to "Approval" as requested
- **Icons**: All icons are displayed in green color (not based on API)
- **Menu Items**:
  1. **My Request** - Redirects to general inventory request form
  2. **Approval Waiting** - Shows approval requests from `/api/inventory/waitings`
  3. **Approval in Branch** - Shows approval requests (currently same API, future endpoint change planned)
  4. **Approval from Branch** - Shows approval requests (currently same API, future endpoint change planned)
  5. **My Receive** - Shows received items from `/api/inventory/exports`

#### Individual Pages

##### My Request Page (`my_request_page.dart`)
- Automatically redirects to the general `InventoryRequestForm`
- Maintains same functionality as regular users

##### Approval Pages (`approval_waiting_page.dart`, `approval_in_branch_page.dart`, `approval_from_branch_page.dart`)
- **API Endpoint**: Currently all use `/api/inventory/waitings` (as specified)
- **Future**: Will be updated to use different endpoints for branch-specific approvals
- **UI**: Displays approval requests in list format with:
  - Request title (pink color)
  - Submission date
  - Type: "for Office" (fixed text)
  - Status: "Supervisor Pending ..." (green badge)
  - Requestor profile picture

##### My Receive Page (`my_receive_page.dart`)
- **API Endpoint**: `/api/inventory/exports`
- **UI**: Similar to approval pages but with "EXPORTED" status (yellow badge)

##### Requestor Detail Page (`requestor_detail_page.dart`)
- **API Endpoint**: `/api/inventory/exported/{uid}` for fetching details
- **Actions**:
  - **Receive Button**: Calls `PUT /api/inventory/received/{uid}` to mark item as received
  - **Cancel Button**: Allows cancellation of the request
- **UI**: Shows detailed information about the request and requested items

## API Endpoints Used

### Current Implementation
1. **User Roles**: `GET /api/display/me`
2. **Approval Requests**: `GET /api/inventory/waitings`
3. **Received Items**: `GET /api/inventory/exports`
4. **Request Details**: `GET /api/inventory/exported/{uid}`
5. **Receive Item**: `PUT /api/inventory/received/{uid}`

### Future Updates
- **Approval in Branch**: Will use a different endpoint (to be specified)
- **Approval from Branch**: Will use a different endpoint (to be specified)

## File Structure

```
lib/home/dashboard/Card/inventory/
├── inventory_management_page.dart          # Main page with role detection
├── inventory_request_form.dart             # General request form
├── inventory_app_bar.dart                  # Common app bar
└── admin_hq/                              # AdminHQ-specific pages
    ├── index.dart                          # Export all AdminHQ pages
    ├── inventory_admin_hq_page.dart        # Main AdminHQ interface
    ├── my_request_page.dart                # My Request page
    ├── approval_waiting_page.dart          # Approval Waiting page
    ├── approval_in_branch_page.dart        # Approval in Branch page
    ├── approval_from_branch_page.dart      # Approval from Branch page
    ├── my_receive_page.dart                # My Receive page
    └── requestor_detail_page.dart          # Requestor Detail page
```

## Key Features

### 1. Automatic Role Detection
- System automatically detects user role on page load
- No manual role selection required
- Seamless user experience

### 2. Role-Based Access Control
- AdminHQ users see specialized interface
- Regular users see standard inventory management
- Access denied for unauthorized users

### 3. Consistent UI/UX
- All AdminHQ pages follow the same design pattern
- Green icons as specified
- Pink borders and accents for approval items
- Responsive design for different screen sizes

### 4. Error Handling
- Comprehensive error handling for API failures
- User-friendly error messages
- Retry functionality for failed requests

### 5. Loading States
- Loading indicators during API calls
- Smooth transitions between states
- Optimized performance with caching

## Implementation Notes

### 1. Base URL Configuration
- Uses environment variable `BASE_URL` from `.env` file
- Follows the same pattern as other services in the application

### 2. Authentication
- Uses Bearer token authentication
- Automatically handles token validation
- Redirects to login if authentication fails

### 3. Image Handling
- Supports both full URLs and relative paths
- Falls back to placeholder icons if images fail to load
- Uses the same image base URL as other parts of the application

### 4. State Management
- Uses Flutter's built-in state management
- Proper disposal of controllers and timers
- Memory-efficient implementation

## Testing

### 1. Role Detection
- Test with AdminHQ user role
- Test with regular user role
- Test with no role/unauthorized user

### 2. API Integration
- Test all API endpoints
- Test error scenarios (network failure, invalid responses)
- Test loading and error states

### 3. Navigation
- Test navigation between all AdminHQ pages
- Test back navigation
- Test deep linking

## Future Enhancements

### 1. Additional Roles
- Extend system to support other roles (Procurement, OfficeAdmin, etc.)
- Create role-specific interfaces for each role type

### 2. Advanced Permissions
- Implement fine-grained permissions within roles
- Add permission-based feature toggles

### 3. Caching
- Implement more sophisticated caching for API responses
- Add offline support for critical functionality

### 4. Analytics
- Track user interactions with approval workflows
- Monitor approval processing times
- Generate reports for management

## Conclusion

The role-based inventory management system provides a robust, scalable foundation for managing different user access levels. The implementation follows Flutter best practices and maintains consistency with the existing application architecture. The system is ready for production use and can be easily extended to support additional roles and features in the future.
