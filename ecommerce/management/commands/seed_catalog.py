"""Create a repeatable demo catalog for local development."""

from decimal import Decimal

from django.contrib.auth import get_user_model
from django.contrib.auth.models import Group
from django.core.management.base import BaseCommand
from django.db import transaction
from django.utils.text import slugify

from ecommerce.models import Attribute, AttributeValue, Category, Product, SellerRating


DEMO_SELLERS = (
    {
        "key": "vader-direct",
        "username": "demo_catalog_seller_vader",
        "email": "vader.seller@example.test",
        "store_name": "VADER Direct",
        "is_verified_seller": True,
    },
    {
        "key": "northline-tech",
        "username": "demo_catalog_seller_northline",
        "email": "northline.seller@example.test",
        "store_name": "Northline Tech",
        "is_verified_seller": True,
    },
    {
        "key": "sound-square",
        "username": "demo_catalog_seller_sound_square",
        "email": "sound.square.seller@example.test",
        "store_name": "SoundSquare",
        "is_verified_seller": False,
    },
    {
        "key": "homecraft-market",
        "username": "demo_catalog_seller_homecraft",
        "email": "homecraft.seller@example.test",
        "store_name": "HomeCraft Market",
        "is_verified_seller": False,
    },
)

DEMO_CUSTOMERS = (
    {
        "key": "customer-01",
        "username": "demo_catalog_customer_01",
        "email": "catalog.customer.01@example.test",
    },
    {
        "key": "customer-02",
        "username": "demo_catalog_customer_02",
        "email": "catalog.customer.02@example.test",
    },
    {
        "key": "customer-03",
        "username": "demo_catalog_customer_03",
        "email": "catalog.customer.03@example.test",
    },
)

CATEGORY_SELLERS = {
    "Mobile & Wearables": "vader-direct",
    "Computers": "northline-tech",
    "Gaming": "northline-tech",
    "Audio": "sound-square",
    "Home & Kitchen": "homecraft-market",
    "Accessories": "vader-direct",
}

DEMO_SELLER_RATINGS = {
    "customer-01": {
        "vader-direct": 5,
        "northline-tech": 5,
        "sound-square": 4,
        "homecraft-market": 5,
    },
    "customer-02": {
        "vader-direct": 4,
        "northline-tech": 5,
        "sound-square": 5,
        "homecraft-market": 4,
    },
    "customer-03": {
        "vader-direct": 5,
        "northline-tech": 4,
        "sound-square": 4,
        "homecraft-market": 5,
    },
}


DEMO_PRODUCTS = (
    {
        "category": "Mobile & Wearables",
        "name": "VADER Nova X1 Smartphone",
        "slug": "vader-nova-x1-smartphone",
        "description": "A bright 6.7-inch display, all-day battery life, and a versatile camera system.",
        "price": "699.00",
        "stock": 24,
        "image_url": "https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Mobile & Wearables",
        "name": "VADER Vista 11 Tablet",
        "slug": "vader-vista-11-tablet",
        "description": "A lightweight tablet made for streaming, notes, reading, and everyday work.",
        "price": "449.00",
        "stock": 18,
        "image_url": "https://images.unsplash.com/photo-1544244015-0df4b3ffc6b0?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Mobile & Wearables",
        "name": "VADER Orbit S2 Smartwatch",
        "slug": "vader-orbit-s2-smartwatch",
        "description": "Fitness tracking, notifications, and a crisp always-on display in a slim case.",
        "price": "179.00",
        "stock": 35,
        "image_url": "https://images.unsplash.com/photo-1523275335684-37898b6baf30?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Computers",
        "name": "VADER Apex 14 Laptop",
        "slug": "vader-apex-14-laptop",
        "description": "A portable performance laptop with a sharp display and a quiet keyboard.",
        "price": "1099.00",
        "stock": 9,
        "image_url": "https://images.unsplash.com/photo-1496181133206-80ce9b88a853?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Computers",
        "name": "VADER CoreBox Mini PC",
        "slug": "vader-corebox-mini-pc",
        "description": "Compact desktop performance for home offices, media, and daily productivity.",
        "price": "649.00",
        "stock": 14,
        "image_url": "https://images.unsplash.com/photo-1593642632823-8f785ba67e45?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Computers",
        "name": "VADER Canvas 27 QHD Monitor",
        "slug": "vader-canvas-27-monitor",
        "description": "A detailed QHD panel with a clean stand and plenty of room for multitasking.",
        "price": "329.00",
        "stock": 21,
        "image_url": "https://images.unsplash.com/photo-1527443224154-c4a3942d3acf?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Gaming",
        "name": "VADER Titan Wireless Controller",
        "slug": "vader-titan-controller",
        "description": "Responsive wireless controls, textured grips, and USB-C charging.",
        "price": "69.00",
        "stock": 52,
        "image_url": "https://images.unsplash.com/photo-1600080972464-8e5f35f63d08?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Gaming",
        "name": "VADER Pulse RGB Gaming Mouse",
        "slug": "vader-pulse-rgb-mouse",
        "description": "A precise lightweight mouse with programmable buttons and adjustable lighting.",
        "price": "49.00",
        "stock": 61,
        "image_url": "https://images.unsplash.com/photo-1527814050087-3793815479db?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Gaming",
        "name": "VADER Arcadia Gaming Headset",
        "slug": "vader-arcadia-headset",
        "description": "Comfortable over-ear sound with a clear microphone for long gaming sessions.",
        "price": "89.00",
        "stock": 38,
        "image_url": "https://images.unsplash.com/photo-1599669454699-248893623440?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Audio",
        "name": "VADER Wave ANC Headphones",
        "slug": "vader-wave-anc-headphones",
        "description": "Immersive wireless listening with active noise cancellation and soft ear cushions.",
        "price": "199.00",
        "stock": 27,
        "image_url": "https://images.unsplash.com/photo-1505740420928-5e560c06d30e?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Audio",
        "name": "VADER Echo Mini Speaker",
        "slug": "vader-echo-mini-speaker",
        "description": "Room-filling Bluetooth sound in a small, travel-friendly speaker.",
        "price": "59.00",
        "stock": 46,
        "image_url": "https://images.unsplash.com/photo-1608043152269-423dbba4e7e1?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Audio",
        "name": "VADER Studio USB Microphone",
        "slug": "vader-studio-usb-microphone",
        "description": "Clear plug-and-play voice capture for calls, streaming, and podcasts.",
        "price": "129.00",
        "stock": 19,
        "image_url": "https://images.unsplash.com/photo-1590602847861-f357a9332bbc?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Home & Kitchen",
        "name": "VADER Aero 6L Air Fryer",
        "slug": "vader-aero-air-fryer",
        "description": "A roomy digital air fryer with simple controls and easy-to-clean parts.",
        "price": "159.00",
        "stock": 16,
        "image_url": "https://images.unsplash.com/photo-1585515320310-259814833e62?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Home & Kitchen",
        "name": "VADER Brew One Coffee Maker",
        "slug": "vader-brew-one-coffee-maker",
        "description": "Consistent morning coffee with a compact design and straightforward controls.",
        "price": "119.00",
        "stock": 22,
        "image_url": "https://images.unsplash.com/photo-1517668808822-9ebb02f2a0e6?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Home & Kitchen",
        "name": "VADER CleanBot S5 Robot Vacuum",
        "slug": "vader-cleanbot-s5-vacuum",
        "description": "Scheduled floor cleaning with smart navigation and automatic recharging.",
        "price": "399.00",
        "stock": 11,
        "image_url": "https://images.unsplash.com/photo-1558317374-067fb5f30001?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Accessories",
        "name": "VADER Volt 65W USB-C Charger",
        "slug": "vader-volt-65w-charger",
        "description": "Fast compact charging for laptops, tablets, phones, and everyday accessories.",
        "price": "45.00",
        "stock": 64,
        "image_url": "https://images.unsplash.com/photo-1583863788434-e58a36330cf0?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Accessories",
        "name": "VADER Link 8-in-1 USB-C Hub",
        "slug": "vader-link-8-in-1-hub",
        "description": "Add display, storage, network, and charging ports through one USB-C cable.",
        "price": "79.00",
        "stock": 43,
        "image_url": "https://images.unsplash.com/photo-1625842268584-8f3296236761?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Accessories",
        "name": "VADER Shield Laptop Backpack",
        "slug": "vader-shield-backpack",
        "description": "A weather-resistant everyday backpack with a padded laptop compartment.",
        "price": "69.00",
        "stock": 29,
        "image_url": "https://images.unsplash.com/photo-1553062407-98eeb64c6a62?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Mobile & Wearables",
        "name": "VADER Nova Lite Smartphone",
        "slug": "vader-nova-lite-smartphone",
        "description": "A practical 5G phone with a bright display, dependable battery, and dual cameras.",
        "price": "399.00",
        "stock": 31,
        "image_url": "https://images.unsplash.com/photo-1598327105666-5b89351aff97?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Mobile & Wearables",
        "name": "VADER Vista Mini 8 Tablet",
        "slug": "vader-vista-mini-8-tablet",
        "description": "A compact tablet for reading, video calls, travel, and casual streaming.",
        "price": "249.00",
        "stock": 19,
        "image_url": "https://images.unsplash.com/photo-1544244015-0df4b3ffc6b0?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Mobile & Wearables",
        "name": "VADER Orbit Fit Band",
        "slug": "vader-orbit-fit-band",
        "description": "A lightweight activity band with sleep tracking and phone notifications.",
        "price": "79.00",
        "stock": 48,
        "image_url": "https://images.unsplash.com/photo-1579586337278-3befd40fd17a?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Mobile & Wearables",
        "name": "VADER AirBuds Pro Earbuds",
        "slug": "vader-airbuds-pro-earbuds",
        "description": "Pocket-sized wireless earbuds with clear calls and active noise cancellation.",
        "price": "129.00",
        "stock": 34,
        "image_url": "https://images.unsplash.com/photo-1606220945770-b5b6c2c55bf1?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Mobile & Wearables",
        "name": "VADER ChargeGo 10000 Power Bank",
        "slug": "vader-chargego-10000-power-bank",
        "description": "A slim portable battery with fast USB-C charging for phones and wearables.",
        "price": "49.00",
        "stock": 57,
        "image_url": "https://images.unsplash.com/photo-1583863788434-e58a36330cf0?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Computers",
        "name": "VADER Forge 16 Creator Laptop",
        "slug": "vader-forge-16-creator-laptop",
        "description": "A high-performance laptop for demanding creative projects and multitasking.",
        "price": "1599.00",
        "stock": 5,
        "image_url": "https://images.unsplash.com/photo-1496181133206-80ce9b88a853?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Computers",
        "name": "VADER DeskPro Tower PC",
        "slug": "vader-deskpro-tower-pc",
        "description": "A quiet desktop computer built for office work, development, and media creation.",
        "price": "1199.00",
        "stock": 7,
        "image_url": "https://images.unsplash.com/photo-1593640408182-31c70c8268f5?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Computers",
        "name": "VADER View 24 FHD Monitor",
        "slug": "vader-view-24-fhd-monitor",
        "description": "A crisp everyday monitor with slim bezels and flexible input options.",
        "price": "189.00",
        "stock": 26,
        "image_url": "https://images.unsplash.com/photo-1585792180666-f7347c490ee2?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Computers",
        "name": "VADER Slim Keys Wireless Keyboard",
        "slug": "vader-slim-keys-wireless-keyboard",
        "description": "A low-profile keyboard that switches quickly between three paired devices.",
        "price": "89.00",
        "stock": 41,
        "image_url": "https://images.unsplash.com/photo-1587829741301-dc798b83add3?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Computers",
        "name": "VADER Pocket 1TB Portable SSD",
        "slug": "vader-pocket-1tb-portable-ssd",
        "description": "Fast portable storage in a durable compact enclosure with USB-C connectivity.",
        "price": "119.00",
        "stock": 26,
        "image_url": "https://images.unsplash.com/photo-1597872200969-2b65d56bd16b?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Gaming",
        "name": "VADER Striker TKL Keyboard",
        "slug": "vader-striker-tkl-keyboard",
        "description": "A compact mechanical gaming keyboard with responsive switches and RGB lighting.",
        "price": "109.00",
        "stock": 28,
        "image_url": "https://images.unsplash.com/photo-1587829741301-dc798b83add3?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Gaming",
        "name": "VADER Phantom Gaming Chair",
        "slug": "vader-phantom-gaming-chair",
        "description": "An adjustable high-back chair with supportive padding for long sessions.",
        "price": "249.00",
        "stock": 12,
        "image_url": "https://images.unsplash.com/photo-1598550476439-6847785fcea6?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Gaming",
        "name": "VADER Arena XL Desk Mat",
        "slug": "vader-arena-xl-desk-mat",
        "description": "A wide non-slip desk mat with a smooth surface for keyboard and mouse control.",
        "price": "29.00",
        "stock": 74,
        "image_url": "https://images.unsplash.com/photo-1527814050087-3793815479db?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Gaming",
        "name": "VADER Quest Handheld Console",
        "slug": "vader-quest-handheld-console",
        "description": "Portable gaming with a bright display, responsive controls, and expandable storage.",
        "price": "349.00",
        "stock": 15,
        "image_url": "https://images.unsplash.com/photo-1486401899868-0e435ed85128?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Gaming",
        "name": "VADER Sprint Wireless Gaming Mouse",
        "slug": "vader-sprint-wireless-gaming-mouse",
        "description": "A lightweight wireless mouse with a precise sensor and long battery life.",
        "price": "79.00",
        "stock": 46,
        "image_url": "https://images.unsplash.com/photo-1527814050087-3793815479db?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Audio",
        "name": "VADER Studio Monitor Pair",
        "slug": "vader-studio-monitor-pair",
        "description": "Balanced desktop speakers for music production, editing, and focused listening.",
        "price": "249.00",
        "stock": 17,
        "image_url": "https://images.unsplash.com/photo-1608043152269-423dbba4e7e1?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Audio",
        "name": "VADER Clip Go Speaker",
        "slug": "vader-clip-go-speaker",
        "description": "A durable compact Bluetooth speaker designed for travel and everyday listening.",
        "price": "39.00",
        "stock": 59,
        "image_url": "https://images.unsplash.com/photo-1608043152269-423dbba4e7e1?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Audio",
        "name": "VADER Stream Audio Interface",
        "slug": "vader-stream-audio-interface",
        "description": "A two-input USB-C interface for instruments, microphones, and streaming setups.",
        "price": "149.00",
        "stock": 20,
        "image_url": "https://images.unsplash.com/photo-1590602847861-f357a9332bbc?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Audio",
        "name": "VADER Vinyl One Turntable",
        "slug": "vader-vinyl-one-turntable",
        "description": "A belt-drive record player with simple controls and Bluetooth output.",
        "price": "229.00",
        "stock": 10,
        "image_url": "https://images.unsplash.com/photo-1461360228754-6e81c478b882?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Audio",
        "name": "VADER Cast USB Microphone",
        "slug": "vader-cast-usb-microphone",
        "description": "A compact USB microphone for meetings, voice recording, and live streams.",
        "price": "89.00",
        "stock": 25,
        "image_url": "https://images.unsplash.com/photo-1590602847861-f357a9332bbc?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Home & Kitchen",
        "name": "VADER Steel Electric Kettle",
        "slug": "vader-steel-electric-kettle",
        "description": "A fast-boiling stainless steel kettle with automatic shutoff and dry-boil protection.",
        "price": "69.00",
        "stock": 33,
        "image_url": "https://images.unsplash.com/photo-1594213114663-d94db9b17125?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Home & Kitchen",
        "name": "VADER MixPro Blender",
        "slug": "vader-mixpro-blender",
        "description": "A powerful countertop blender for smoothies, sauces, soups, and crushed ice.",
        "price": "139.00",
        "stock": 21,
        "image_url": "https://images.unsplash.com/photo-1570222094114-d054a817e56b?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Home & Kitchen",
        "name": "VADER Toast Duo Toaster",
        "slug": "vader-toast-duo-toaster",
        "description": "A compact two-slice toaster with browning control and a removable crumb tray.",
        "price": "49.00",
        "stock": 0,
        "image_url": "https://images.unsplash.com/photo-1556911220-bff31c812dba?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Home & Kitchen",
        "name": "VADER PureAir 300 Air Purifier",
        "slug": "vader-pureair-300-air-purifier",
        "description": "Quiet room air cleaning with a replaceable HEPA filter and smart scheduling.",
        "price": "219.00",
        "stock": 13,
        "image_url": "https://images.unsplash.com/photo-1585771724684-38269d6639fd?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Home & Kitchen",
        "name": "VADER Crisp Compact Toaster Oven",
        "slug": "vader-crisp-compact-toaster-oven",
        "description": "A space-saving oven for toast, quick meals, reheating, and small-batch baking.",
        "price": "129.00",
        "stock": 18,
        "image_url": "https://images.unsplash.com/photo-1556911220-bff31c812dba?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Accessories",
        "name": "VADER CableKit 6-in-1",
        "slug": "vader-cablekit-6-in-1",
        "description": "A travel-ready cable set for common USB-C and USB-A charging connections.",
        "price": "24.00",
        "stock": 96,
        "image_url": "https://images.unsplash.com/photo-1615526675159-e248c3021d3f?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Accessories",
        "name": "VADER MagStand Wireless Charger",
        "slug": "vader-magstand-wireless-charger",
        "description": "A stable angled charging stand that keeps compatible phones visible while charging.",
        "price": "39.00",
        "stock": 58,
        "image_url": "https://images.unsplash.com/photo-1583863788434-e58a36330cf0?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Accessories",
        "name": "VADER Carry 13 Laptop Sleeve",
        "slug": "vader-carry-13-laptop-sleeve",
        "description": "A padded water-resistant sleeve for compact laptops and everyday commuting.",
        "price": "32.00",
        "stock": 47,
        "image_url": "https://images.unsplash.com/photo-1553062407-98eeb64c6a62?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Accessories",
        "name": "VADER PowerCore 20000 Power Bank",
        "slug": "vader-powercore-20000-power-bank",
        "description": "A high-capacity portable battery with two outputs and fast USB-C recharging.",
        "price": "69.00",
        "stock": 38,
        "image_url": "https://images.unsplash.com/photo-1583863788434-e58a36330cf0?auto=format&fit=crop&w=900&q=80",
    },
    {
        "category": "Accessories",
        "name": "VADER Flex Aluminum Laptop Stand",
        "slug": "vader-flex-aluminum-laptop-stand",
        "description": "A ventilated adjustable stand that raises laptops for a more comfortable workspace.",
        "price": "54.00",
        "stock": 44,
        "image_url": "https://images.unsplash.com/photo-1593642632823-8f785ba67e45?auto=format&fit=crop&w=900&q=80",
    },
)


# Structured specifications make the storefront filters useful without
# adding category-specific columns to Product.
DEMO_PRODUCT_ATTRIBUTES = {
    "vader-nova-x1-smartphone": {
        "Product type": "Smartphone",
        "Storage": "256 GB",
        "Connectivity": "5G",
        "Display size": "6.7 inch",
    },
    "vader-vista-11-tablet": {
        "Product type": "Tablet",
        "Storage": "128 GB",
        "Connectivity": "Wi-Fi",
        "Display size": "11 inch",
    },
    "vader-orbit-s2-smartwatch": {
        "Product type": "Smartwatch",
        "Connectivity": "Bluetooth",
        "Feature": "Fitness tracking",
    },
    "vader-apex-14-laptop": {
        "Product type": "Laptop",
        "Memory": "16 GB",
        "Storage": "512 GB SSD",
        "Display size": "14 inch",
        "Resolution": "QHD",
    },
    "vader-corebox-mini-pc": {
        "Product type": "Mini PC",
        "Memory": "16 GB",
        "Storage": "1 TB SSD",
        "Connectivity": "Wi-Fi 6",
    },
    "vader-canvas-27-monitor": {
        "Product type": "Monitor",
        "Display size": "27 inch",
        "Resolution": "QHD",
        "Connectivity": "DisplayPort",
    },
    "vader-titan-controller": {
        "Product type": "Controller",
        "Connectivity": "Wireless",
        "Feature": "USB-C charging",
    },
    "vader-pulse-rgb-mouse": {
        "Product type": "Gaming mouse",
        "Connectivity": "Wired",
        "Feature": "RGB lighting",
    },
    "vader-arcadia-headset": {
        "Product type": "Gaming headset",
        "Connectivity": "Wired",
        "Feature": "Built-in microphone",
    },
    "vader-wave-anc-headphones": {
        "Product type": "Headphones",
        "Connectivity": "Wireless",
        "Feature": "Noise cancellation",
    },
    "vader-echo-mini-speaker": {
        "Product type": "Speaker",
        "Connectivity": "Bluetooth",
        "Feature": "Portable",
    },
    "vader-studio-usb-microphone": {
        "Product type": "Microphone",
        "Connectivity": "USB",
        "Feature": "Cardioid capture",
    },
    "vader-aero-air-fryer": {
        "Product type": "Air fryer",
        "Capacity": "6 L",
        "Feature": "Digital controls",
    },
    "vader-brew-one-coffee-maker": {
        "Product type": "Coffee maker",
        "Feature": "Compact design",
    },
    "vader-cleanbot-s5-vacuum": {
        "Product type": "Robot vacuum",
        "Connectivity": "Wi-Fi",
        "Feature": "Smart navigation",
    },
    "vader-volt-65w-charger": {
        "Product type": "Charger",
        "Connectivity": "USB-C",
        "Power": "65 W",
    },
    "vader-link-8-in-1-hub": {
        "Product type": "USB-C hub",
        "Connectivity": "USB-C",
        "Feature": "8 ports",
    },
    "vader-shield-backpack": {
        "Product type": "Backpack",
        "Feature": "Water resistant",
        "Compatibility": "Laptop",
    },
    "vader-nova-lite-smartphone": {
        "Product type": "Smartphone",
        "Storage": "128 GB",
        "Connectivity": "5G",
        "Display size": "6.5 inch",
    },
    "vader-vista-mini-8-tablet": {
        "Product type": "Tablet",
        "Storage": "64 GB",
        "Connectivity": "Wi-Fi",
        "Display size": "8.7 inch",
    },
    "vader-orbit-fit-band": {
        "Product type": "Fitness band",
        "Connectivity": "Bluetooth",
        "Feature": "Sleep tracking",
    },
    "vader-airbuds-pro-earbuds": {
        "Product type": "Earbuds",
        "Connectivity": "Wireless",
        "Feature": "Noise cancellation",
    },
    "vader-chargego-10000-power-bank": {
        "Product type": "Power bank",
        "Capacity": "10000 mAh",
        "Connectivity": "USB-C",
        "Power": "20 W",
    },
    "vader-forge-16-creator-laptop": {
        "Product type": "Laptop",
        "Memory": "32 GB",
        "Storage": "1 TB SSD",
        "Display size": "16 inch",
        "Resolution": "QHD",
    },
    "vader-deskpro-tower-pc": {
        "Product type": "Desktop PC",
        "Memory": "32 GB",
        "Storage": "1 TB SSD",
        "Connectivity": "Ethernet",
    },
    "vader-view-24-fhd-monitor": {
        "Product type": "Monitor",
        "Display size": "24 inch",
        "Resolution": "Full HD",
        "Connectivity": "HDMI",
    },
    "vader-slim-keys-wireless-keyboard": {
        "Product type": "Keyboard",
        "Connectivity": "Wireless",
        "Feature": "Multi-device pairing",
    },
    "vader-pocket-1tb-portable-ssd": {
        "Product type": "Portable SSD",
        "Storage": "1 TB SSD",
        "Connectivity": "USB-C",
        "Compatibility": "Computer",
    },
    "vader-striker-tkl-keyboard": {
        "Product type": "Gaming keyboard",
        "Connectivity": "Wired",
        "Feature": "RGB lighting",
    },
    "vader-phantom-gaming-chair": {
        "Product type": "Gaming chair",
        "Feature": "Adjustable support",
        "Compatibility": "Gaming desk",
    },
    "vader-arena-xl-desk-mat": {
        "Product type": "Desk mat",
        "Feature": "Non-slip base",
        "Compatibility": "Keyboard and mouse",
    },
    "vader-quest-handheld-console": {
        "Product type": "Handheld console",
        "Storage": "256 GB",
        "Connectivity": "Wi-Fi",
        "Feature": "Expandable storage",
    },
    "vader-sprint-wireless-gaming-mouse": {
        "Product type": "Gaming mouse",
        "Connectivity": "Wireless",
        "Feature": "Adjustable sensitivity",
    },
    "vader-studio-monitor-pair": {
        "Product type": "Studio speakers",
        "Connectivity": "Wired",
        "Feature": "Balanced sound",
    },
    "vader-clip-go-speaker": {
        "Product type": "Speaker",
        "Connectivity": "Bluetooth",
        "Feature": "Water resistant",
    },
    "vader-stream-audio-interface": {
        "Product type": "Audio interface",
        "Connectivity": "USB-C",
        "Feature": "Two inputs",
    },
    "vader-vinyl-one-turntable": {
        "Product type": "Turntable",
        "Connectivity": "Bluetooth",
        "Feature": "Belt drive",
    },
    "vader-cast-usb-microphone": {
        "Product type": "Microphone",
        "Connectivity": "USB",
        "Feature": "Cardioid capture",
    },
    "vader-steel-electric-kettle": {
        "Product type": "Electric kettle",
        "Capacity": "1.7 L",
        "Power": "2200 W",
        "Feature": "Automatic shutoff",
    },
    "vader-mixpro-blender": {
        "Product type": "Blender",
        "Capacity": "1.5 L",
        "Power": "1000 W",
        "Feature": "Pulse mode",
    },
    "vader-toast-duo-toaster": {
        "Product type": "Toaster",
        "Capacity": "2 slices",
        "Power": "850 W",
        "Feature": "Browning control",
    },
    "vader-pureair-300-air-purifier": {
        "Product type": "Air purifier",
        "Connectivity": "Wi-Fi",
        "Capacity": "35 square meters",
        "Feature": "HEPA filter",
    },
    "vader-crisp-compact-toaster-oven": {
        "Product type": "Toaster oven",
        "Capacity": "18 L",
        "Power": "1400 W",
        "Feature": "Temperature control",
    },
    "vader-cablekit-6-in-1": {
        "Product type": "Cable kit",
        "Connectivity": "USB-C",
        "Compatibility": "Phone and computer",
        "Feature": "6 cables",
    },
    "vader-magstand-wireless-charger": {
        "Product type": "Wireless charger",
        "Connectivity": "Wireless",
        "Power": "15 W",
        "Compatibility": "Smartphone",
    },
    "vader-carry-13-laptop-sleeve": {
        "Product type": "Laptop sleeve",
        "Compatibility": "13-inch laptop",
        "Feature": "Water resistant",
    },
    "vader-powercore-20000-power-bank": {
        "Product type": "Power bank",
        "Capacity": "20000 mAh",
        "Connectivity": "USB-C",
        "Power": "30 W",
    },
    "vader-flex-aluminum-laptop-stand": {
        "Product type": "Laptop stand",
        "Compatibility": "Laptop",
        "Feature": "Adjustable height",
    },
}

ATTRIBUTE_POSITIONS = {
    "Product type": 10,
    "Connectivity": 20,
    "Memory": 30,
    "Storage": 40,
    "Display size": 50,
    "Resolution": 60,
    "Capacity": 70,
    "Power": 80,
    "Compatibility": 90,
    "Feature": 100,
}


class Command(BaseCommand):
    help = "Creates or updates the local demo product catalog without deleting data."

    @transaction.atomic
    def handle(self, *args, **options):
        created_count = 0
        updated_count = 0
        user_model = get_user_model()

        seller_group, _ = Group.objects.get_or_create(name="Sellers")
        sellers = {}
        for definition in DEMO_SELLERS:
            seller, created = user_model.objects.get_or_create(
                username=definition["username"],
                defaults={
                    "email": definition["email"],
                    "store_name": definition["store_name"],
                    "is_verified_seller": definition["is_verified_seller"],
                    "is_active": True,
                },
            )
            if created:
                seller.set_unusable_password()
                seller.save(update_fields=("password",))
            seller.groups.add(seller_group)
            sellers[definition["key"]] = seller

        customers = {}
        for definition in DEMO_CUSTOMERS:
            customer, created = user_model.objects.get_or_create(
                username=definition["username"],
                defaults={
                    "email": definition["email"],
                    "is_active": True,
                },
            )
            if created:
                customer.set_unusable_password()
                customer.save(update_fields=("password",))
            customers[definition["key"]] = customer

        for item in DEMO_PRODUCTS:
            category, _ = Category.objects.get_or_create(name=item["category"])
            seller = sellers[CATEGORY_SELLERS[item["category"]]]
            product, created = Product.objects.update_or_create(
                slug=item["slug"],
                defaults={
                    "name": item["name"],
                    "description": item["description"],
                    "price": Decimal(item["price"]),
                    "stock": item["stock"],
                    "category": category,
                    "seller": seller,
                    "image_url": item["image_url"],
                    "is_active": True,
                },
            )
            if created:
                created_count += 1
            else:
                updated_count += 1

            product_values = []
            for attribute_name, value_name in DEMO_PRODUCT_ATTRIBUTES.get(
                item["slug"], {}
            ).items():
                attribute, _ = Attribute.objects.get_or_create(
                    name=attribute_name,
                    defaults={"position": ATTRIBUTE_POSITIONS[attribute_name]},
                )
                attribute.categories.add(category)
                value, _ = AttributeValue.objects.get_or_create(
                    attribute=attribute,
                    slug=slugify(value_name),
                    defaults={"name": value_name},
                )
                product_values.append(value)

            product.attribute_values.set(product_values)

        rating_count = 0
        for customer_key, seller_scores in DEMO_SELLER_RATINGS.items():
            customer = customers[customer_key]
            for seller_key, score in seller_scores.items():
                SellerRating.objects.update_or_create(
                    customer=customer,
                    seller=sellers[seller_key],
                    defaults={"score": score},
                )
                rating_count += 1

        self.stdout.write(
            self.style.SUCCESS(
                f"Catalog ready: {created_count} created, {updated_count} updated, "
                f"{rating_count} seller ratings ready."
            )
        )
