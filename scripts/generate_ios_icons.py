#!/usr/bin/env python3
"""
Generate iOS app icons for Wake Up Sunshine app.
Creates a sun icon similar to the Android version.
"""

from PIL import Image, ImageDraw
import os

def create_sun_icon(size):
    """Create a sun icon with the specified size."""
    # Create a new image with orange background
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Colors
    sun_yellow = (255, 215, 0, 255)  # Gold/Yellow
    sun_orange = (255, 107, 26, 255)  # Primary orange
    
    # Background circle (orange)
    margin = size * 0.05
    bg_center = size / 2
    bg_radius = (size / 2) - margin
    draw.ellipse(
        [bg_center - bg_radius, bg_center - bg_radius, 
         bg_center + bg_radius, bg_center + bg_radius],
        fill=sun_orange
    )
    
    # Sun circle (yellow)
    sun_center = size / 2
    sun_radius = size * 0.28
    draw.ellipse(
        [sun_center - sun_radius, sun_center - sun_radius,
         sun_center + sun_radius, sun_center + sun_radius],
        fill=sun_yellow
    )
    
    # Sun rays
    ray_length = size * 0.15
    ray_width = size * 0.06
    num_rays = 8
    
    import math
    
    for i in range(num_rays):
        angle = (i * 360 / num_rays) * math.pi / 180
        
        # Ray start (edge of sun circle)
        start_x = sun_center + (sun_radius + size * 0.02) * math.cos(angle)
        start_y = sun_center + (sun_radius + size * 0.02) * math.sin(angle)
        
        # Ray end
        end_x = sun_center + (sun_radius + ray_length) * math.cos(angle)
        end_y = sun_center + (sun_radius + ray_length) * math.sin(angle)
        
        # Draw ray as a thick line
        perp_angle = angle + math.pi / 2
        half_width = ray_width / 2
        
        points = [
            (start_x + half_width * math.cos(perp_angle), 
             start_y + half_width * math.sin(perp_angle)),
            (start_x - half_width * math.cos(perp_angle), 
             start_y - half_width * math.sin(perp_angle)),
            (end_x - half_width * 0.5 * math.cos(perp_angle), 
             end_y - half_width * 0.5 * math.sin(perp_angle)),
            (end_x + half_width * 0.5 * math.cos(perp_angle), 
             end_y + half_width * 0.5 * math.sin(perp_angle)),
        ]
        draw.polygon(points, fill=sun_yellow)
    
    return img

def main():
    # iOS icon sizes needed
    sizes = {
        'AppIcon-20.png': 20,
        'AppIcon-29.png': 29,
        'AppIcon-40.png': 40,
        'AppIcon-40-1.png': 40,
        'AppIcon-40-2.png': 40,
        'AppIcon-58.png': 58,
        'AppIcon-58-1.png': 58,
        'AppIcon-60.png': 60,
        'AppIcon-76.png': 76,
        'AppIcon-80.png': 80,
        'AppIcon-80-1.png': 80,
        'AppIcon-87.png': 87,
        'AppIcon-120.png': 120,
        'AppIcon-120-1.png': 120,
        'AppIcon-152.png': 152,
        'AppIcon-167.png': 167,
        'AppIcon-180.png': 180,
        'AppIcon-1024.png': 1024,
    }
    
    output_dir = 'ios/WakeUpSunshine/Resources/Assets.xcassets/AppIcon.appiconset'
    os.makedirs(output_dir, exist_ok=True)
    
    for filename, size in sizes.items():
        print(f'Generating {filename} ({size}x{size})...')
        icon = create_sun_icon(size)
        icon.save(os.path.join(output_dir, filename))
    
    print('All icons generated successfully!')

if __name__ == '__main__':
    main()