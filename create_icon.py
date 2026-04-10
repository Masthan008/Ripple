import os
from PIL import Image

def create_notification_icon(source_path, base_dest_path):
    # Base sizes for notification icons
    sizes = {
        'mdpi': 24,
        'hdpi': 36,
        'xhdpi': 48,
        'xxhdpi': 72,
        'xxxhdpi': 96
    }
    
    try:
        # Open source image
        img = Image.open(source_path).convert("RGBA")
        
        # Create a white silhouette based on the alpha channel
        # or brightness if alpha is mostly opaque
        # Let's extract the alpha channel to use as the mask
        # If the image doesn't have much transparency but has a black/white logo,
        # we can use the inverse of the brightness as the alpha.
        # But assuming it's a proper PNG logo with transparent background:
        
        # Check if the image has a transparent background
        extrema = img.getextrema()
        has_alpha = extrema[3][0] < 255
        
        mask = img.split()[3] if has_alpha else img.convert("L").point(lambda x: 255 - x)
        
        # Create a pure white image
        white_img = Image.new("RGBA", img.size, (255, 255, 255, 255))
        # Apply the mask so it's a white silhouette on transparent background
        white_img.putalpha(mask)
        
        for density, size in sizes.items():
            # Resize
            resized = white_img.resize((size, size), Image.Resampling.LANCZOS)
            
            # Ensure directory exists
            dest_dir = os.path.join(base_dest_path, f"drawable-{density}")
            if not os.path.exists(dest_dir):
                # If drawable-XX doesn't exist, try mipmap-XX (some apps use mipmap for all icons)
                # But Android notifications look specifically in drawable first. Let's create it.
                os.makedirs(dest_dir, exist_ok=True)
                
            dest_file = os.path.join(dest_dir, "ic_stat_onesignal_default.png")
            resized.save(dest_file, "PNG")
            print(f"Created {dest_file}")
            
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    source = "c:/valli/RIPPLE/ripple/assets/images/ripple_logo.png"
    base_dest = "c:/valli/RIPPLE/ripple/android/app/src/main/res"
    create_notification_icon(source, base_dest)
