-- Seed learning cards for the Micro-Learning Engine (T57)
INSERT INTO learning_cards (title, content, category, difficulty, points_reward) VALUES
('What is Carbon Footprint?', 
 'Your carbon footprint is the total greenhouse gases (CO₂ and equivalents) released by your activities — transport, food, energy use. The average Indian emits ~2 tonnes CO₂/year vs global avg of 4.8 tonnes.',
 'basics', 'beginner', 5),

('The 1.5°C Boundary',
 'The Paris Agreement aims to limit global warming to 1.5°C above pre-industrial levels. Beyond this, we risk triggering climate tipping points — irreversible changes like ice sheet collapse, coral reef die-off, and permafrost thaw releasing massive methane.',
 'climate_science', 'beginner', 5),

('Urban Heat Island Effect',
 'Cities are 2–5°C hotter than surrounding areas due to concrete absorbing heat and lack of trees. Each 10% increase in green cover reduces urban temperature by ~0.5°C. Planting trees in cities is one of the most cost-effective climate solutions.',
 'urban_environment', 'intermediate', 10),

('The Spillover Effect',
 'Research shows that adopting one eco-habit often triggers others — called the "positive spillover effect." People who start cycling to work are 73% more likely to also reduce meat consumption within 6 months.',
 'behavior', 'intermediate', 10),

('PM2.5 and Your Lungs',
 'PM2.5 (particles <2.5 micrometres) penetrate deep into lungs and bloodstream. Long-term exposure at 35μg/m³+ doubles risk of heart disease. Delhi averages 90μg/m³ in winter — 3x the WHO safe limit.',
 'air_quality', 'beginner', 5),

('Personal Carbon Trading (PCT)',
 'PCT is a policy concept where every citizen gets a carbon allowance. Those who live sustainably can sell unused allowances to higher emitters. Apps like Grevidea make this citizen-level trading possible for the first time.',
 'policy', 'advanced', 15),

('Circular Economy Basics',
 'The circular economy follows: Refuse → Reduce → Reuse → Repair → Recycle. Borrowing a drill instead of buying one avoids ~25kg CO₂ manufacturing emissions. The sharing economy can reduce material consumption by up to 20%.',
 'circular_economy', 'beginner', 5),

('Eco-Anxiety is Real',
 'Climate anxiety affects 68% of adults worldwide. The American Psychological Association recognizes it as a valid psychological response. Action-based coping — doing something concrete — is proven more effective than avoidance.',
 'mental_health', 'beginner', 5),

('Methane: The Short-Term Climate Bomb',
 'Methane (CH₄) is 80x more potent than CO₂ over 20 years, though it dissipates faster. Cattle farming accounts for 14.5% of global greenhouse gas emissions. Reducing beef consumption once a week saves ~0.5 tonnes CO₂ per year.',
 'food_systems', 'intermediate', 10),

('RTI: Your Environmental Weapon',
 'India''s RTI Act 2005 gives every citizen the right to request information from government bodies within 30 days. You can request environmental impact assessments, pollution inspection records, and government spending on green infrastructure.',
 'civic_rights', 'advanced', 15),

('Passive Transport Detection',
 'Smartphones can infer travel mode (walking, cycling, driving, train) from GPS speed, accelerometer patterns, and cell tower transitions — without user input. This enables automatic carbon logging with 94% accuracy.',
 'technology', 'advanced', 15),

('India''s Climate Vulnerability',
 'India is ranked among the top 10 most climate-vulnerable nations. By 2050, heat stress could reduce outdoor working hours by 15%, threatening 75 million livelihoods. The Himalayan glaciers (India''s water tower) are retreating at 40cm/year.',
 'india_specific', 'intermediate', 10)
ON CONFLICT DO NOTHING;
