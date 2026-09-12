package core

import (
	"sync"
	"time"
)

type lruCache struct {
	mu       sync.RWMutex
	capacity int
	items    map[int64]*Gallery
	order    []int64
}

func newLRUCache(capacity int) *lruCache {
	return &lruCache{
		capacity: capacity,
		items:    make(map[int64]*Gallery),
		order:    make([]int64, 0, capacity),
	}
}

func (c *lruCache) Get(id int64) (*Gallery, bool) {
	c.mu.Lock()
	defer c.mu.Unlock()

	item, exists := c.items[id]
	if !exists {
		return nil, false
	}

	for i, k := range c.order {
		if k == id {
			c.order = append(c.order[:i], c.order[i+1:]...)
			break
		}
	}
	c.order = append(c.order, id)
	return item, true
}

func (c *lruCache) Put(gallery *Gallery) {
	if gallery == nil || gallery.ID == 0 {
		return
	}
	c.mu.Lock()
	defer c.mu.Unlock()

	if _, exists := c.items[gallery.ID]; exists {
		for i, k := range c.order {
			if k == gallery.ID {
				c.order = append(c.order[:i], c.order[i+1:]...)
				break
			}
		}
	} else if len(c.order) >= c.capacity {
		oldest := c.order[0]
		c.order = c.order[1:]
		delete(c.items, oldest)
	}

	c.order = append(c.order, gallery.ID)
	c.items[gallery.ID] = gallery
}

type ggCache struct {
	mu        sync.RWMutex
	script    string
	fetchedAt time.Time
	ttl       time.Duration
}

func newGgCache(ttl time.Duration) *ggCache {
	return &ggCache{ttl: ttl}
}

func (g *ggCache) Get() (string, bool) {
	g.mu.RLock()
	defer g.mu.RUnlock()
	if g.script != "" && time.Since(g.fetchedAt) < g.ttl {
		return g.script, true
	}
	return "", false
}

func (g *ggCache) Set(script string) {
	g.mu.Lock()
	defer g.mu.Unlock()
	g.script = script
	g.fetchedAt = time.Now()
}
