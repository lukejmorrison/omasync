//! Pending offers that make the bar chip breathe green until Dad accepts.

use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};

use crate::home_dir;

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct InboxFile {
    pub path: String,
    pub name: String,
    pub size: u64,
    #[serde(default = "default_on")]
    pub on: bool,
}

fn default_on() -> bool {
    true
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct WaitingOffer {
    pub id: String,
    pub name: String,
    pub from: String,
    #[serde(default)]
    pub files: Vec<InboxFile>,
}

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct Inbox {
    #[serde(default)]
    pub offers: Vec<WaitingOffer>,
}

impl WaitingOffer {
    pub fn file_count(&self) -> usize {
        self.files.len()
    }

    pub fn selected_count(&self) -> usize {
        self.files.iter().filter(|f| f.on).count()
    }

    pub fn size(&self) -> u64 {
        self.files.iter().map(|f| f.size).sum()
    }

    pub fn selected_size(&self) -> u64 {
        self.files.iter().filter(|f| f.on).map(|f| f.size).sum()
    }
}

impl Inbox {
    pub fn waiting_count(&self) -> usize {
        self.offers.len()
    }

    pub fn waiting_files(&self) -> usize {
        self.offers.iter().map(|o| o.files.len()).sum()
    }

    pub fn names(&self) -> Vec<String> {
        self.offers.iter().map(|o| o.name.clone()).collect()
    }

    pub fn offer_mut(&mut self, id: &str) -> Option<&mut WaitingOffer> {
        self.offers.iter_mut().find(|o| o.id == id)
    }

    pub fn toggle(&mut self, id: &str, path: &str) -> bool {
        let Some(offer) = self.offer_mut(id) else {
            return false;
        };
        let Some(file) = offer.files.iter_mut().find(|f| f.path == path || f.name == path)
        else {
            return false;
        };
        file.on = !file.on;
        true
    }

    pub fn select_all(&mut self, id: &str, on: bool) -> bool {
        let Some(offer) = self.offer_mut(id) else {
            return false;
        };
        for f in &mut offer.files {
            f.on = on;
        }
        true
    }

    /// Keep only the files Dad did not accept. Drop the offer if none remain.
    pub fn accept(&mut self, id: &str) -> Option<WaitingOffer> {
        let idx = self.offers.iter().position(|o| o.id == id)?;
        let offer = &mut self.offers[idx];
        let (taken, leftover): (Vec<InboxFile>, Vec<InboxFile>) =
            offer.files.drain(..).partition(|f| f.on);
        if taken.is_empty() {
            offer.files = leftover;
            return None;
        }
        let snapshot = WaitingOffer {
            id: offer.id.clone(),
            name: offer.name.clone(),
            from: offer.from.clone(),
            files: taken,
        };
        if leftover.is_empty() {
            self.offers.remove(idx);
        } else {
            offer.files = leftover;
        }
        Some(snapshot)
    }

    pub fn dismiss(&mut self, id: &str) -> bool {
        let before = self.offers.len();
        self.offers.retain(|o| o.id != id);
        self.offers.len() != before
    }
}

pub fn inbox_path() -> PathBuf {
    home_dir().join(".local/share/omasync/inbox.json")
}

pub fn load_inbox(path: &Path) -> Inbox {
    let Ok(text) = std::fs::read_to_string(path) else {
        return Inbox::default();
    };
    serde_json::from_str(&text).unwrap_or_default()
}

pub fn save_inbox(path: &Path, inbox: &Inbox) -> std::io::Result<()> {
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    let text = serde_json::to_string_pretty(inbox).unwrap_or_else(|_| "{}".into());
    std::fs::write(path, text)
}

/// First-run demo so the bar chip has something to pulse — a Videos folder
/// plus the smaller "For Dad" stack.
pub fn demo_inbox() -> Inbox {
    Inbox {
        offers: vec![
            WaitingOffer {
                id: "videos".into(),
                name: "Videos".into(),
                from: "Luke's phone".into(),
                files: vec![
                    file("Videos/family-dinner.mp4", "family-dinner.mp4", 82_400_000),
                    file("Videos/garden-walk.mp4", "garden-walk.mp4", 41_200_000),
                    file("Videos/2026-08-dock.mp4", "2026-08-dock.mp4", 64_800_000),
                    file("Videos/workshop.mp4", "workshop.mp4", 28_100_000),
                ],
            },
            WaitingOffer {
                id: "fordad".into(),
                name: "For Dad".into(),
                from: "Luke's phone".into(),
                files: vec![
                    file("For Dad/letter.pdf", "letter.pdf", 220_000),
                    file("For Dad/recipes.pdf", "recipes.pdf", 1_120_000),
                    file("For Dad/omarchy-setup.md", "omarchy-setup.md", 14_000),
                ],
            },
        ],
    }
}

fn file(path: &str, name: &str, size: u64) -> InboxFile {
    InboxFile {
        path: path.into(),
        name: name.into(),
        size,
        on: true,
    }
}

/// Load, or seed the demo offer the first time so Dad's chip has work.
pub fn load_or_seed(path: &Path) -> Inbox {
    if path.exists() {
        load_inbox(path)
    } else {
        let inbox = demo_inbox();
        let _ = save_inbox(path, &inbox);
        inbox
    }
}

pub fn write_receipt(dest: &Path, offer: &WaitingOffer) -> std::io::Result<PathBuf> {
    std::fs::create_dir_all(dest)?;
    let receipt = dest.join(format!("accepted-{}.txt", offer.id));
    let mut body = format!(
        "OmaSync accepted \"{}\" from {}\n{} file(s)\n\n",
        offer.name,
        offer.from,
        offer.files.len()
    );
    for f in &offer.files {
        body.push_str(&format!("  {}\t{}\n", f.size, f.path));
    }
    std::fs::write(&receipt, body)?;
    Ok(receipt)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn demo_has_videos() {
        let inbox = demo_inbox();
        assert_eq!(inbox.waiting_count(), 2);
        assert_eq!(inbox.names(), vec!["Videos", "For Dad"]);
        assert!(inbox.waiting_files() >= 4);
    }

    #[test]
    fn toggle_and_accept_keeps_unticked() {
        let mut inbox = demo_inbox();
        assert!(inbox.toggle("videos", "Videos/workshop.mp4"));
        let taken = inbox.accept("videos").expect("accept");
        assert_eq!(taken.files.len(), 3);
        assert_eq!(inbox.waiting_count(), 2);
        let leftover = inbox.offer_mut("videos").unwrap();
        assert_eq!(leftover.files.len(), 1);
        assert_eq!(leftover.files[0].name, "workshop.mp4");
    }

    #[test]
    fn accept_all_drops_offer() {
        let mut inbox = demo_inbox();
        inbox.select_all("fordad", true);
        let taken = inbox.accept("fordad").unwrap();
        assert_eq!(taken.files.len(), 3);
        assert_eq!(inbox.waiting_count(), 1);
        assert_eq!(inbox.names(), vec!["Videos"]);
    }
}
