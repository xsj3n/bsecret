# to gen some tests
for i in {1..3}; do
  echo foo >> "$i.key" 
done

echo foo >> "r.pem.dat"
