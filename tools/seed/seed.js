// Run from tools/seed with: npm run seed
// Fixed IDs are used, so running it again updates the data and makes no copies.

const fs = require('fs');
const path = require('path');
// firebase-admin 14 needs these separate imports. The old single 'admin' object was removed.
const { initializeApp, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, FieldValue, GeoPoint } = require('firebase-admin/firestore');
const { DEMO_PASSWORD, users, restaurants, menuItems } = require('./data');

function initFirebase() {
  // Emulator mode: no key needed.
  if (process.env.FIRESTORE_EMULATOR_HOST) {
    initializeApp({ projectId: 'ada-rasa-foods' });
    console.log('Using the Firebase Emulator.');
    return;
  }

  const keyPath = path.join(__dirname, 'serviceAccountKey.json');
  if (!fs.existsSync(keyPath)) {
    console.error('serviceAccountKey.json not found in tools/seed.');
    console.error('Download it from Firebase console: Project settings, Service accounts.');
    process.exit(1);
  }
  initializeApp({ credential: cert(require(keyPath)) });
}

// Creates the Auth account, or updates it if it already exists.
async function upsertAuthUser(user) {
  const data = {
    email: user.email,
    password: DEMO_PASSWORD,
    displayName: user.name,
    emailVerified: true,
  };
  try {
    await getAuth().getUser(user.uid);
    await getAuth().updateUser(user.uid, data);
  } catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
    await getAuth().createUser({ uid: user.uid, ...data });
  }
}

function userDoc(user) {
  const doc = {
    name: user.name,
    email: user.email,
    phone: '',
    role: user.role,
    createdAt: FieldValue.serverTimestamp(),
  };
  if (user.restaurantId) doc.restaurantId = user.restaurantId;
  if (user.role === 'rider') doc.isOnline = user.isOnline;
  return doc;
}

function restaurantDoc(restaurant) {
  return {
    name: restaurant.name,
    cuisine: restaurant.cuisine,
    ownerId: restaurant.ownerId,
    imageUrl: '',
    address: restaurant.address,
    location: new GeoPoint(restaurant.lat, restaurant.lng),
    isOpen: true,
    isActive: true,
    createdAt: FieldValue.serverTimestamp(),
  };
}

function menuItemDoc(item) {
  return {
    name: item.name,
    description: item.description,
    price: item.price,
    imageUrl: '',
    category: item.category,
    available: item.available ?? true,
  };
}

async function main() {
  initFirebase();
  const db = getFirestore();

  for (const user of users) {
    await upsertAuthUser(user);
  }
  console.log(`Auth users: ${users.length}`);

  // One batch is fine here: we write far less than the 500 limit.
  const batch = db.batch();
  let itemCount = 0;

  for (const user of users) {
    batch.set(db.collection('users').doc(user.uid), userDoc(user));
  }

  for (const restaurant of restaurants) {
    const restaurantRef = db.collection('restaurants').doc(restaurant.id);
    batch.set(restaurantRef, restaurantDoc(restaurant));

    for (const item of menuItems[restaurant.id] ?? []) {
      batch.set(restaurantRef.collection('menuItems').doc(item.id), menuItemDoc(item));
      itemCount++;
    }
  }

  await batch.commit();
  console.log(`User docs: ${users.length}`);
  console.log(`Restaurants: ${restaurants.length}`);
  console.log(`Menu items: ${itemCount}`);
  console.log(`Done. Demo password for all seed users: ${DEMO_PASSWORD}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Seed failed:', error.message);
    process.exit(1);
  });