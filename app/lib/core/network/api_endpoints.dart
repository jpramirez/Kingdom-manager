class ApiEndpoints {
  ApiEndpoints._();

  // Auth
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String magicLink = '/auth/magic-link';
  static const String magicLinkVerify = '/auth/magic-link/verify';

  // Users
  static const String me = '/users/me';

  // Households
  static const String households = '/households/';
  static String household(String id) => '/households/$id';
  static String refreshInvite(String id) => '/households/$id/refresh-invite';
  static const String joinHousehold = '/households/join';
  static String members(String hid) => '/households/$hid/members/';
  static String member(String hid, String mid) => '/households/$hid/members/$mid';

  // Family (unified)
  static String family(String hid) => '/households/$hid/family';

  // Family Profiles
  static String familyProfiles(String hid) => '/households/$hid/profiles';
  static String familyProfile(String hid, String pid) =>
      '/households/$hid/profiles/$pid';

  // Chores
  static String chores(String hid) => '/households/$hid/chores/';
  static String chore(String hid, String id) => '/households/$hid/chores/$id';
  static String choreAssignments(String hid, String cid) => '/households/$hid/chores/$cid/assignments';
  static String assignment(String hid, String aid) => '/households/$hid/chores/assignments/$aid';
  static String myAssignments(String hid) => '/households/$hid/chores/assignments/my';
  static String todayAssignments(String hid) => '/households/$hid/chores/assignments/today';

  // Calendar
  static String calendar(String hid) => '/households/$hid/calendar/';
  static String calendarEvent(String hid, String id) => '/households/$hid/calendar/$id';

  // Meals
  static String recipes(String hid) => '/households/$hid/meals/recipes/';
  static String recipe(String hid, String id) => '/households/$hid/meals/recipes/$id';
  static String mealPlan(String hid) => '/households/$hid/meals/plan';
  static String mealRequests(String hid) => '/households/$hid/meals/requests/';
  static String mealRequest(String hid, String id) => '/households/$hid/meals/requests/$id';

  // Grocery
  static String groceryLists(String hid) => '/households/$hid/grocery/lists/';
  static String groceryList(String hid, String id) => '/households/$hid/grocery/lists/$id';
  static String groceryItems(String hid, String lid) => '/households/$hid/grocery/lists/$lid/items/';
  static String groceryItem(String hid, String lid, String iid) => '/households/$hid/grocery/lists/$lid/items/$iid';
  static String groceryItemsBatch(String hid, String lid) => '/households/$hid/grocery/lists/$lid/items/batch';

  // Approvals
  static String approvals(String hid) => '/households/$hid/approvals/';
  static String approvalsAll(String hid) => '/households/$hid/approvals/all';
  static String approvalApprove(String hid, String id) => '/households/$hid/approvals/$id/approve';
  static String approvalReject(String hid, String id) => '/households/$hid/approvals/$id/reject';

  // Comments
  static String comments(String hid, String entityType, String entityId) =>
      '/households/$hid/comments/$entityType/$entityId/';
  static String comment(String hid, String commentId) =>
      '/households/$hid/comments/$commentId';

  // Notifications
  static const String notifications = '/notifications';
  static const String notificationsRead = '/notifications/read';
  static const String deviceToken = '/notifications/device-token';

  // AI Assistant
  static String aiConversations(String hid) => '/households/$hid/ai/conversations';
  static String aiConversation(String hid, String cid) => '/households/$hid/ai/conversations/$cid';
  static String aiMessages(String hid, String cid) => '/households/$hid/ai/conversations/$cid/messages';
  static String aiOnboardingStart(String hid) => '/households/$hid/ai/onboarding/start';
  static String aiOnboardingAdvance(String hid, String cid) => '/households/$hid/ai/onboarding/$cid/advance';
  static String aiMemory(String hid) => '/households/$hid/ai/memory';
  static String aiMemoryItem(String hid, String mid) => '/households/$hid/ai/memory/$mid';
}
