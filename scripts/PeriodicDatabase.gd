extends Node
class_name PeriodicDatabase

# PeriodicDatabase.gd
# Data for the 3D Nexus of Elements

const ELEMENTS = {
	1: {"symbol": "H", "name": "Hidrogênio", "group": 1, "period": 1, "mass": 1.008, "electronegativity": 2.20, "radius": 37, "color": Color(0.8, 0.8, 0.8), "curiosity": "O elemento mais abundante do universo."},
	2: {"symbol": "He", "name": "Hélio", "group": 18, "period": 1, "mass": 4.0026, "electronegativity": 0, "radius": 31, "color": Color(0.8, 1.0, 1.0), "curiosity": "Usado em balões e dirigíveis."},
	3: {"symbol": "Li", "name": "Lítio", "group": 1, "period": 2, "mass": 6.94, "electronegativity": 0.98, "radius": 152, "color": Color(0.8, 0.4, 1.0), "curiosity": "Essencial para baterias de celular."},
	4: {"symbol": "Be", "name": "Berílio", "group": 2, "period": 2, "mass": 9.0122, "electronegativity": 1.57, "radius": 112, "color": Color(0.6, 1.0, 0.4), "curiosity": "Usado em ligas para naves espaciais."},
	5: {"symbol": "B", "name": "Boro", "group": 13, "period": 2, "mass": 10.81, "electronegativity": 2.04, "radius": 82, "color": Color(1.0, 0.7, 0.5), "curiosity": "Usado em vidros resistentes ao calor."},
	6: {"symbol": "C", "name": "Carbono", "group": 14, "period": 2, "mass": 12.011, "electronegativity": 2.55, "radius": 77, "color": Color(0.2, 0.2, 0.2), "curiosity": "Base de toda a vida na Terra."},
	7: {"symbol": "N", "name": "Nitrogênio", "group": 15, "period": 2, "mass": 14.007, "electronegativity": 3.04, "radius": 75, "color": Color(0.2, 0.4, 1.0), "curiosity": "78% do ar que respiramos."},
	8: {"symbol": "O", "name": "Oxigênio", "group": 16, "period": 2, "mass": 15.999, "electronegativity": 3.44, "radius": 73, "color": Color(1.0, 0.1, 0.1), "curiosity": "Necessário para a nossa respiração."},
	9: {"symbol": "F", "name": "Flúor", "group": 17, "period": 2, "mass": 18.998, "electronegativity": 3.98, "radius": 71, "color": Color(0.7, 1.0, 0.3), "curiosity": "Previne cáries nos dentes."},
	10: {"symbol": "Ne", "name": "Neônio", "group": 18, "period": 2, "mass": 20.180, "electronegativity": 0, "radius": 69, "color": Color(0.7, 0.9, 1.0), "curiosity": "Usado em letreiros luminosos."},
	11: {"symbol": "Na", "name": "Sódio", "group": 1, "period": 3, "mass": 22.990, "electronegativity": 0.93, "radius": 186, "color": Color(0.5, 0.3, 0.9), "curiosity": "Presente no sal de cozinha."},
	12: {"symbol": "Mg", "name": "Magnésio", "group": 2, "period": 3, "mass": 24.305, "electronegativity": 1.31, "radius": 160, "color": Color(0.4, 0.8, 0.2), "curiosity": "Importante para a clorofila das plantas."},
	13: {"symbol": "Al", "name": "Alumínio", "group": 13, "period": 3, "mass": 26.982, "electronegativity": 1.61, "radius": 143, "color": Color(0.7, 0.7, 0.7), "curiosity": "Usado em latas de refrigerante."},
	15: {"symbol": "P", "name": "Fósforo", "group": 15, "period": 3, "mass": 30.974, "electronegativity": 2.19, "radius": 106, "color": Color(1.0, 0.5, 0.0), "curiosity": "Essencial para o nosso DNA."},
	16: {"symbol": "S", "name": "Enxofre", "group": 16, "period": 3, "mass": 32.06, "electronegativity": 2.58, "radius": 102, "color": Color(1.0, 1.0, 0.0), "curiosity": "Usado na fabricação de pólvora."},
	17: {"symbol": "Cl", "name": "Cloro", "group": 17, "period": 3, "mass": 35.45, "electronegativity": 3.16, "radius": 99, "color": Color(0.8, 1.0, 0.3), "curiosity": "Usado para purificar a água."},
	18: {"symbol": "Ar", "name": "Argônio", "group": 18, "period": 3, "mass": 39.948, "electronegativity": 0, "radius": 97, "color": Color(0.7, 0.8, 1.0), "curiosity": "Usado dentro de lâmpadas comuns."},
	19: {"symbol": "K", "name": "Potássio", "group": 1, "period": 4, "mass": 39.098, "electronegativity": 0.82, "radius": 227, "color": Color(0.6, 0.3, 0.8), "curiosity": "Abundante em bananas."},
	20: {"symbol": "Ca", "name": "Cálcio", "group": 2, "period": 4, "mass": 40.078, "electronegativity": 1.00, "radius": 197, "color": Color(0.3, 0.8, 0.3), "curiosity": "Essencial para ossos e dentes."},
	26: {"symbol": "Fe", "name": "Ferro", "group": 8, "period": 4, "mass": 55.845, "electronegativity": 1.83, "radius": 126, "color": Color(0.6, 0.6, 0.6), "curiosity": "Presente na hemoglobina do sangue."},
	29: {"symbol": "Cu", "name": "Cobre", "group": 11, "period": 4, "mass": 63.546, "electronegativity": 1.90, "radius": 128, "color": Color(0.7, 0.4, 0.2), "curiosity": "Excelente condutor de eletricidade."},
	30: {"symbol": "Zn", "name": "Zinco", "group": 12, "period": 4, "mass": 65.38, "electronegativity": 1.65, "radius": 134, "color": Color(0.5, 0.5, 0.6), "curiosity": "Ajuda no sistema imunológico."},
	35: {"symbol": "Br", "name": "Bromo", "group": 17, "period": 4, "mass": 79.904, "electronegativity": 2.96, "radius": 114, "color": Color(0.6, 0.1, 0.1), "curiosity": "Único ametal líquido."},
	47: {"symbol": "Ag", "name": "Prata", "group": 11, "period": 5, "mass": 107.87, "electronegativity": 1.93, "radius": 144, "color": Color(0.9, 0.9, 0.9), "curiosity": "Usada em joias e fotografia."},
	53: {"symbol": "I", "name": "Iodo", "group": 17, "period": 5, "mass": 126.90, "electronegativity": 2.66, "radius": 133, "color": Color(0.4, 0.0, 0.4), "curiosity": "Essencial para a glândula tireoide."},
	56: {"symbol": "Ba", "name": "Bário", "group": 2, "period": 6, "mass": 137.33, "electronegativity": 0.89, "radius": 222, "color": Color(0.1, 0.6, 0.1), "curiosity": "Usado em contrastes para exames de raio-X."},
	78: {"symbol": "Pt", "name": "Platina", "group": 10, "period": 6, "mass": 195.08, "electronegativity": 2.28, "radius": 139, "color": Color(0.8, 0.8, 0.9), "curiosity": "Metal nobre usado em catalisadores."},
	79: {"symbol": "Au", "name": "Ouro", "group": 11, "period": 6, "mass": 196.97, "electronegativity": 2.54, "radius": 144, "color": Color(1.0, 0.8, 0.0), "curiosity": "O metal mais maleável e valioso."},
	80: {"symbol": "Hg", "name": "Mercúrio", "group": 12, "period": 6, "mass": 200.59, "electronegativity": 2.00, "radius": 151, "color": Color(0.8, 0.8, 0.8), "curiosity": "Único metal líquido em temperatura ambiente."},
	92: {"symbol": "U", "name": "Urânio", "group": 3, "period": 7, "mass": 238.03, "electronegativity": 1.38, "radius": 186, "color": Color(0.2, 0.8, 0.2), "curiosity": "Usado como combustível em usinas nucleares."}
	# ... (More elements will be added later)
}

func get_element(atomic_number: int) -> Dictionary:
	return ELEMENTS.get(atomic_number, {})

func get_all_elements() -> Dictionary:
	return ELEMENTS
