// Demo data for the seed script. Prices are whole rupees (int).
// imageUrl is empty, so the app shows a default image until the owner uploads a photo.

const DEMO_PASSWORD = 'AdaRasa@123';

const users = [
  { uid: 'seed_admin', name: 'Ada Rasa Admin', email: 'admin@adarasa.test', role: 'admin' },

  { uid: 'seed_owner_1', name: 'Kasun Perera', email: 'owner1@adarasa.test', role: 'restaurant', restaurantId: 'restaurant_1' },
  { uid: 'seed_owner_2', name: 'Nimali Fernando', email: 'owner2@adarasa.test', role: 'restaurant', restaurantId: 'restaurant_2' },
  { uid: 'seed_owner_3', name: 'Ruwan Silva', email: 'owner3@adarasa.test', role: 'restaurant', restaurantId: 'restaurant_3' },
  { uid: 'seed_owner_4', name: 'Chen Wei', email: 'owner4@adarasa.test', role: 'restaurant', restaurantId: 'restaurant_4' },
  { uid: 'seed_owner_5', name: 'Dilshan Jayasuriya', email: 'owner5@adarasa.test', role: 'restaurant', restaurantId: 'restaurant_5' },

  { uid: 'seed_rider_1', name: 'Saman Kumara', email: 'rider1@adarasa.test', role: 'rider', isOnline: false },
  { uid: 'seed_rider_2', name: 'Pradeep Bandara', email: 'rider2@adarasa.test', role: 'rider', isOnline: false },
];

const restaurants = [
  {
    id: 'restaurant_1',
    name: 'Kottu Corner',
    cuisine: 'Sri Lankan',
    ownerId: 'seed_owner_1',
    address: '112 Galle Road, Bambalapitiya, Colombo 04',
    lat: 6.8885,
    lng: 79.8567,
  },
  {
    id: 'restaurant_2',
    name: "Amma's Rice & Curry",
    cuisine: 'Sri Lankan',
    ownerId: 'seed_owner_2',
    address: '45 Station Road, Wellawatte, Colombo 06',
    lat: 6.8746,
    lng: 79.8605,
  },
  {
    id: 'restaurant_3',
    name: 'Hopper Hut',
    cuisine: 'Sri Lankan',
    ownerId: 'seed_owner_3',
    address: '28 Dharmapala Mawatha, Kollupitiya, Colombo 03',
    lat: 6.911,
    lng: 79.851,
  },
  {
    id: 'restaurant_4',
    name: 'Golden Wok',
    cuisine: 'Chinese',
    ownerId: 'seed_owner_4',
    address: '76 D. S. Senanayake Mawatha, Borella, Colombo 08',
    lat: 6.9147,
    lng: 79.8778,
  },
  {
    id: 'restaurant_5',
    name: 'Slice Street Pizza',
    cuisine: 'Pizza',
    ownerId: 'seed_owner_5',
    address: '15 Havelock Road, Havelock Town, Colombo 05',
    lat: 6.8826,
    lng: 79.867,
  },
];

// One item is not available, to test the "Not available" label.
const menuItems = {
  restaurant_1: [
    { id: 'item_1_1', name: 'Chicken Kottu', price: 1200, category: 'Kottu', description: 'Chopped roti with chicken, egg and vegetables.' },
    { id: 'item_1_2', name: 'Cheese Kottu', price: 1500, category: 'Kottu', description: 'Chicken kottu mixed with melted cheese.' },
    { id: 'item_1_3', name: 'Egg Kottu', price: 950, category: 'Kottu', description: 'Classic kottu with egg and leeks.' },
    { id: 'item_1_4', name: 'Dolphin Kottu', price: 1400, category: 'Kottu', description: 'Fried roti pieces in a spicy chicken curry.', available: false },
    { id: 'item_1_5', name: 'Vegetable Kottu', price: 850, category: 'Kottu', description: 'Kottu with fresh vegetables only.' },
    { id: 'item_1_6', name: 'Iced Milo', price: 450, category: 'Drinks', description: 'Cold chocolate malt drink.' },
  ],
  restaurant_2: [
    { id: 'item_2_1', name: 'Chicken Rice & Curry', price: 950, category: 'Rice', description: 'Rice with chicken curry, dhal and two vegetables.' },
    { id: 'item_2_2', name: 'Fish Rice & Curry', price: 1050, category: 'Rice', description: 'Rice with fish ambul thiyal and vegetables.' },
    { id: 'item_2_3', name: 'Vegetable Rice & Curry', price: 650, category: 'Rice', description: 'Rice with four vegetable curries and papadam.' },
    { id: 'item_2_4', name: 'Lamprais', price: 1600, category: 'Rice', description: 'Rice and curries baked in a banana leaf.' },
    { id: 'item_2_5', name: 'Watalappan', price: 400, category: 'Desserts', description: 'Coconut milk and jaggery pudding.' },
    { id: 'item_2_6', name: 'Faluda', price: 550, category: 'Drinks', description: 'Rose milk drink with ice cream and jelly.' },
  ],
  restaurant_3: [
    { id: 'item_3_1', name: 'Egg Hopper', price: 180, category: 'Hoppers', description: 'Crispy hopper with an egg in the middle.' },
    { id: 'item_3_2', name: 'Plain Hopper', price: 80, category: 'Hoppers', description: 'Thin, crispy rice flour hopper.' },
    { id: 'item_3_3', name: 'Milk Hopper', price: 150, category: 'Hoppers', description: 'Hopper with sweet coconut milk.' },
    { id: 'item_3_4', name: 'String Hoppers (10)', price: 450, category: 'Hoppers', description: 'Ten string hoppers with kiri hodi and pol sambol.' },
    { id: 'item_3_5', name: 'Fish Bun', price: 150, category: 'Short eats', description: 'Soft bun filled with spicy fish.' },
    { id: 'item_3_6', name: 'Vegetable Roti', price: 120, category: 'Short eats', description: 'Triangle roti with a potato and vegetable filling.' },
  ],
  restaurant_4: [
    { id: 'item_4_1', name: 'Chicken Fried Rice', price: 1300, category: 'Rice', description: 'Fried rice with chicken, egg and vegetables.' },
    { id: 'item_4_2', name: 'Seafood Fried Rice', price: 1650, category: 'Rice', description: 'Fried rice with prawns, cuttlefish and fish.' },
    { id: 'item_4_3', name: 'Chicken Noodles', price: 1250, category: 'Noodles', description: 'Stir-fried noodles with chicken and vegetables.' },
    { id: 'item_4_4', name: 'Devilled Chicken', price: 1450, category: 'Mains', description: 'Spicy chicken with onions and capsicum.' },
    { id: 'item_4_5', name: 'Hot Butter Cuttlefish', price: 1700, category: 'Mains', description: 'Crispy fried cuttlefish with chilli and butter.' },
    { id: 'item_4_6', name: 'Wonton Soup', price: 750, category: 'Soups', description: 'Clear soup with chicken wontons.' },
  ],
  restaurant_5: [
    { id: 'item_5_1', name: 'Chicken Tikka Pizza', price: 2400, category: 'Pizza', description: 'Medium pizza with spicy chicken tikka and onions.' },
    { id: 'item_5_2', name: 'Cheese Pizza', price: 1900, category: 'Pizza', description: 'Medium pizza with lots of mozzarella.' },
    { id: 'item_5_3', name: 'Sausage Pizza', price: 2200, category: 'Pizza', description: 'Medium pizza with chicken sausages.' },
    { id: 'item_5_4', name: 'Veggie Pizza', price: 2000, category: 'Pizza', description: 'Medium pizza with capsicum, olives and mushrooms.' },
    { id: 'item_5_5', name: 'Garlic Bread', price: 650, category: 'Sides', description: 'Toasted bread with garlic butter.' },
    { id: 'item_5_6', name: 'Chocolate Lava Cake', price: 700, category: 'Desserts', description: 'Warm cake with a soft chocolate centre.' },
  ],
};

module.exports = { DEMO_PASSWORD, users, restaurants, menuItems };